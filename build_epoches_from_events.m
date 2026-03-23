function [flex_ext] = build_epoches_from_events(EEG) 
    % get Flexion start end  and extension start and end
    FS = EEG.event(ismember({EEG.event.type}, {'FlxS'}));
    FE = EEG.event(ismember({EEG.event.type}, {'FlxE'}));%,'ExtS','ExtE'
    ES = EEG.event(ismember({EEG.event.type}, {'ExtS'}));
    EE = EEG.event(ismember({EEG.event.type}, {'ExtE'}));
    n_fs = numel(FS);
    n_es = numel(ES);
    extensions = cell(1, n_es);
    flexions   = cell(1, n_fs);
    flex_desc_raw = {FS.desc}';   % convert cell array → string array
    ext_desc_raw  = {ES.desc}';

    % concatenate FS and FE
    for i = 1:numel(FE)
        if strcmp(FS(i).desc, FE(i).desc)
            t1 = FS(i).latency;
            t2 = FE(i).latency;
            if t2 > t1
                flexions{1,i} = [FS(i).latency, FE(i).latency];
                %flexions{2,i} = flex_desc(i);
            end
        end
    end
    % concatenate ES and EE
    for i = 1:n_es
        if strcmp(ES(i).desc, EE(i).desc)
            t1 = ES(i).latency;
            t2 = EE(i).latency;
            if t2 > t1
                extensions{1,i} = [ES(i).latency, EE(i).latency];
                %extensions{2,i} = ext_desc(i);
            end
        end
    end
    %FS_pam = get_pam_level(FS.desc);
    %ES_pam = get_pam_level(ES.desc);

    % map flexions and extensions with same description

    allLabels = unique(ext_desc_raw, 'stable');
    nLabels   = numel(allLabels);

    % Preallocate struct array with fields
    grouped = struct('label', cell(nLabels,1), ...
                     'flexions', cell(nLabels,1), ...
                     'extensions', cell(nLabels,1));
    
    for i = 1:nLabels
    % Get the label (cellstr vs string)
        if iscell(allLabels)
            label = allLabels{i};      % cell array of char
        else
            label = allLabels(i);      % string array
        end
    
        % Find ALL indices for this label
        fIdx = find(strcmp(flex_desc_raw, label));
        eIdx = find(strcmp(ext_desc_raw,  label));
    
        % Just group, no pairing / trimming by min(...)
        thisFlex = flexions(fIdx);     % cell array of ALL flexions for this label
        thisExt  = extensions(eIdx);   % cell array of ALL extensions for this label
    
        % Optionally, filter out empties or malformed entries
        % (for safety)
        if isempty(thisFlex) == 0 && isempty(thisExt) == 0
            grouped(i).label      = label;
            grouped(i).flexions   = thisFlex;
            grouped(i).extensions = thisExt;
        end
    end 

    % map flexion and extention together as an array
    flex_ext = cell(3, 0);   % start empty, we'll append columns
    col = 1;                 % global column counter
    
    for x = 1:numel(grouped)
        % number of flexions and extensions in this group
        n_flex = numel(grouped(x).flexions);
        n_ext  = numel(grouped(x).extensions);
    
        % only pair up to the smaller of the two
        n_pairs = min(n_flex, n_ext);
    
        for ex = 1:n_pairs
            current_fl = grouped(x).flexions{ex};    % e.g. [t_flex_start t_flex_end]
            current_ex = grouped(x).extensions{ex};  % e.g. [t_ext_start t_ext_end]
    
            % skip if something is empty or too short
            if isempty(current_fl) || isempty(current_ex)
                continue;
            end
            if numel(current_fl) < 2 || numel(current_ex) < 2
                continue;
            end
    
            % condition in time: extension start after flexion end
            if current_ex(1) >= current_fl(2)
                % store [flex_start flex_end ext_end] (like before)
                flex_ext{1, col} = [current_fl, current_ex(2)];
    
                % store PAM level or label (depending on what you want)
                % if grouped(x).label is a single description string:
                flex_ext{2, col} = get_pam_level(grouped(x).label);
                flex_ext{3, col} = grouped(x).label; 
    
                col = col + 1;
            end
        end
    end

end
 

function PAM_levels = get_pam_level(desc)

    % --- normalize input to a cell array of chars ---
    if ischar(desc)
        desc = {desc};                 % wrap char vector into cell
    elseif isstring(desc)
        desc = cellstr(desc);          % convert string → cellstr
    elseif iscell(desc)
        % do nothing — already fine
    else
        error('desc must be a string, char, or cell array of strings.');
    end

    % --- split by '_' ---
    splitDesc = cellfun(@(s) strsplit(s, '_'), desc, 'UniformOutput', false);

    % --- extract the middle number (second element) ---
    midNums = cellfun(@(p) str2double(p{2}), splitDesc);

    % --- optional: remove zeros ---
    PAM_levels = midNums(midNums ~= 0);
end
