function [EEG_warped, labels] = time_warping_channel(EEG, flex_ext)
% EEG        : [nChan x nSamples] continuous EEG
% flex_ext   : 2 x N cell
%              flex_ext{1,k} = [t1 t2 t3] (sample indices in EEG)
%              flex_ext{2,k} = label/desc (unused here)
%
% seg12      : N x 1, sample lengths between t1 and t2
% seg23      : N x 1, sample lengths between t2 and t3
% EEG_warped : 1 x N cell
%              each EEG_warped{k} is [nChan x nTarget] (time-warped epoch)

    [nChan, ~] = size(EEG.data);

    latency = flex_ext(1,:);
    labels = flex_ext(2,:); % 1 x N cell, each is [t1 t2 t3]
    N = numel(latency);

    seg12 = zeros(N,1);
    seg23 = zeros(N,1);

    % ---- 1. Compute segment lengths between landmarks ----
    for i = 1:N
        L = latency{i};          % [t1 t2 t3]
        if numel(L) ~= 3
            error('flex_ext{1,%d} must have 3 elements [t1 t2 t3], but has %d.', ...
                  i, numel(L));
        end

        t1 = L(1);
        t2 = L(2);
        t3 = L(3);

        seg12(i) = t2 - t1 + 1;
        seg23(i) = t3 - t2 + 1;
        
        Ni = t3 - t1 + 1;
        if Ni < 2
            fprintf('Bad epoch %d: t1=%d, t2=%d, t3=%d → Ni=%d\n', i, t1, t2, t3, Ni);
        end
    end

    % ---- 2. Median segment lengths ----
    med12 = round(median(seg12));
    med23 = round(median(seg23));

    % Avoid duplicating the middle landmark: total length
    nTarget = med12 + med23 - 1;

    % ---- 3. Preallocate output ----
    EEG_warped = cell(1, N);
    %labels_warped = cell(1, N);

    % ---- 4. Warp each epoch ----
    for i = 1:N
        L = latency{i};    % [t1 t2 t3]
        t1 = L(1);
        t2 = L(2);
        t3 = L(3);

        % (a) Extract this epoch from continuous EEG: t1..t3
        X = EEG.data(:, t1:t3);        % [nChan x Ni]
        [~, Ni] = size(X);

        % Original time axis for THIS epoch
        t_orig = 1:Ni;            % length Ni, SAME as size(X,2)

        % (b) Build warped source times in ORIGINAL coordinates
        % segment 1: t1 -> t2, med12 samples
        % segment 2: t2 -> t3, med23 samples
        t_src_seg1 = linspace(1, t2 - t1 + 1, med12);   % relative to epoch start
        t_src_seg2 = linspace(t2 - t1 + 1, Ni, med23);  % relative to epoch start

        % Avoid duplicating the middle sample
        t_src = [t_src_seg1, t_src_seg2(2:end)];        % 1 x nTarget

        % (c) Interpolate each channel
        X_warped = zeros(nChan, nTarget);  
        for ch = 1:nChan
            x = X(ch, :);    % 1 x Ni
            X_warped(ch, :) = interp1(t_orig, x, t_src, 'linear');
            % If you ever get edge issues, switch to:
            % X_warped(ch, :) = interp1(t_orig, x, t_src, 'linear', 'extrap')
            
        end
        
        EEG_warped{1,i} = X_warped;
           % [nChan x nTarget]
    end
end
