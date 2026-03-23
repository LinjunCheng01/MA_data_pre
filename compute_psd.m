% compute PSD data for EEGNet and CTNet

dataDir      = 'C:\Users\11210\Desktop\Masterthesis\data\No_epochs';
saveDir_2    = 'C:\Users\11210\Documents\MATLAB\Masterthesis\eeg_PSD\epoch_PSD';

utilsDir     = 'C:\Users\11210\Documents\MATLAB\Masterthesis\utils';   % folder that contains utils.m

%% === PATHS ===
addpath('C:\Users\11210\Documents\MATLAB\eeglab2025.1.0');
eeglab; %closed
addpath(utilsDir);
subjects =15;

% container

for s = subjects
%% === LOOP THROUGH SUBJECTS ===
    fprintf('=== Processing subject %d ===\n', s);
    setFile = sprintf('sub-%d_cleaned_with_ICA.set', s);
    
    %% 1) load .set
    EEG = load_eeglab_set(setFile, dataDir);
    %% 2) build trials + labels
    %[flex_ext] = build_epoches_from_events(EEG);
    flex_ext = build_epoches_from_events(EEG);
    
    %% map with EEG Data
    [nChan, ~] = size(EEG.data);
    
    latency_cells = flex_ext(1,:);   % 1 x N cell, each: [t1 t2 t3]
    label_cells   = flex_ext(2,:);   % 1 x N cell, each: class label (scalar)
    trial_desc = flex_ext(3, :)';
    
    N = numel(latency_cells);
    
    % containers
    X_seg12   = cell(N,1);   % [nChan x len_12_i]
    X_seg23   = cell(N,1);   % [nChan x len_23_i]
    X_concat  = cell(N,1);   % [nChan x (len_12_i + len_23_i)]
    Y         = zeros(N,1);  % numeric label per trial
    
    for i = 1:N
        % ---- 1) get t1, t2, t3 for this trial ----
        L = latency_cells{i};          % [t1 t2 t3]
        if numel(L) ~= 3
            error('latency{%d} must have 3 elements [t1 t2 t3], but has %d.', ...
                  i, numel(L));
        end
        t1 = L(1);
        t2 = L(2);
        t3 = L(3);
    
        % ---- 2) extract segments ----
        % NOTE: use t1:t2-1 and t2:t3-1 to avoid overlapping sample at t2.
        % If your convention is inclusive, change to t1:t2 and t2:t3.
        X_seg12{i} = EEG.data(:, t1:t2);   % [nChan x len_12_i]
        X_seg23{i} = EEG.data(:, t2:t3);   % [nChan x len_23_i]
    
        % ---- 3) concatenate seg12 and seg23 along time dimension ----
        X_concat{i} = [X_seg12{i}, X_seg23{i}];   % [nChan x (len_12_i + len_23_i)]
    
        % ---- 4) store label for this trial ----
        % label_cells{i} might be a scalar or 1x1 cell with scalar
        lab_i = label_cells{i};
        if iscell(lab_i)
            lab_i = lab_i{1};
        end
        Y(i) = lab_i;     % y(i) is now the label for X_concat{i}
    end
    %% PSD Generation
    fs = 500;
    
    % get all trial lengths
    trial_lengths = cellfun(@(z) size(z,2), X_concat);
    minLen = min(trial_lengths);
    
    winLen  = min(round(fs * 1.0), minLen);
    overlap = round(winLen * 0.5);
    nfft    = [];
    
    % determine frequency grid
    example = X_concat{1}(1,1:minLen);
    example = example(:);
    
    [pxx_ex, f] = pwelch(example, winLen, overlap, nfft, fs);
    nFreq = numel(pxx_ex);
    
    X_psd = zeros(N, nChan, nFreq, 'single');
    
    for i = 1:N
        for ch = 1:nChan
            x = X_concat{i}(ch,1:minLen);   % force equal length
            x = x(:);
    
            [pxx, ~] = pwelch(x, winLen, overlap, nfft, fs);
            X_psd(i, ch, :) = single(pxx);
        end
    end
    % Make sure it's a column vector
    trial_desc = trial_desc(:);
    
    % Get unique descriptions and group index for each epoch
    [desc_unique, ~, idx_grp] = unique(trial_desc, 'stable');
    
    nGroups = numel(desc_unique);
    
    [nEp, nChan, nFreq] = size(X_psd);
    
    % Preallocate
    X_psd_avg = zeros(nGroups, nChan, nFreq, 'like', X_psd); % [nGroups x nChan x nFreq]
    Y_psd_avg = zeros(nGroups, 1);
    nTrials_per_desc = zeros(nGroups, 1);
       
    %% split the data and save
    
    [X_train, Y_train, X_val, Y_val, X_test, Y_test] = ...
        split_psd_dataset(X_psd, Y);

    % Save the averaged PSD data and labels to the specified directory
    save(fullfile(saveDir_2, sprintf('sub_%d_psd_epoches.mat', s)), 'X_train', 'Y_train', ...
        "X_val", "Y_val", "X_test", "Y_test",'-v7.3');
    fprintf('file saved\n');
end

function [X_train, Y_train, X_val, Y_val, X_test, Y_test] = ...
    split_psd_dataset(X_psd_avg, Y_psd_avg, trainRatio, valRatio, testRatio, seed)
%SPLIT_PSD_DATASET Shuffle and split PSD data + labels into train/val/test.
%
%   X_psd_avg : [N x nChan x nFreq]
%   Y_psd_avg : [N x 1] (or [1 x N]) label vector, numeric
%
%   Optional:
%     trainRatio, valRatio, testRatio : default 0.7 / 0.15 / 0.15
%     seed                            : RNG seed (default 12345)

    % ---- defaults ----
    if nargin < 3 || isempty(trainRatio), trainRatio = 0.7; end
    if nargin < 4 || isempty(valRatio),   valRatio   = 0.15; end
    if nargin < 5 || isempty(testRatio),  testRatio  = 0.15; end
    if nargin < 6 || isempty(seed),       seed       = 12345; end

    if abs(trainRatio + valRatio + testRatio - 1) > 1e-6
        error('trainRatio + valRatio + testRatio must sum to 1.');
    end

    % ---- basic checks ----
    if ndims(X_psd_avg) ~= 3
        error('X_psd_avg must be [N x nChan x nFreq].');
    end

    N = size(X_psd_avg, 1);
    N_Y = size(Y_psd_avg, 1);

    if N_Y ~= N
        error('Number of labels (%d) does not match N = %d.', N_Y, N);
    end

    Y = Y_psd_avg(:);  % ensure column vector

    % ---- shuffle ----
    rng(seed);
    idx = randperm(N);

    % precompute split indices
    nTrain = floor(trainRatio * N);
    nVal   = floor(valRatio   * N);
    % nTest is whatever remains
    nTest  = N - nTrain - nVal;

    idxTrain = idx(1:nTrain);
    idxVal   = idx(nTrain+1 : nTrain+nVal);
    idxTest  = idx(nTrain+nVal+1 : end);

    % ---- split without extra copies ----
    X_train = X_psd_avg(idxTrain, :, :);
    Y_train = Y(idxTrain);

    X_val   = X_psd_avg(idxVal,   :, :);
    Y_val   = Y(idxVal);

    X_test  = X_psd_avg(idxTest,  :, :);
    Y_test  = Y(idxTest);
end

