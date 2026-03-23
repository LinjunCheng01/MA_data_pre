function [ica_data, PAM_levels] = build_trials_from_events_ica(EEG, ica_act) %PAM_levels,

    % 1) pick only start/end events
    selectedEvents = EEG.event(ismember({EEG.event.type}, ...
                        {'SB_Start_Beep', 'FB_Finish_Beep'}));

    % 2) get descriptions
    desc = {selectedEvents.desc};

    % 3) group by description (start/end pairs)
    grouped_SE = cell(1, numel(desc));
    for i = 1:numel(desc)
        thisDesc = desc{i};
        idx = strcmp(desc, thisDesc);
        theseEvents = selectedEvents(idx);
        grouped_SE{i} = [theseEvents.latency];
    end
    % keep only start–finish pairs (1,3,5,...) 
    grouped_SE = grouped_SE(1:2:end); 

    % 4) get PAM levels from description (middle number) 
    splitDesc = cellfun(@(s) strsplit(s, '_'), desc, 'UniformOutput', false); 
    midNums = cellfun(@(p) str2double(p{2}), splitDesc); 
    PAM_levels = midNums(1:2:end); 
    nonZeroIdx = PAM_levels ~= 0; 
    %disp(nonZeroIdx); 
    PAM_levels = PAM_levels(nonZeroIdx); 

    % 5) compute trial lengths 
    nTrials = numel(grouped_SE); 
    TrialLength = zeros(1, nTrials); 
    for i = 1:nTrials 
        TrialLength(i) = diff(grouped_SE{i}); 
    end 
    % ---- SAFE FILTERING ---- 
    % Define a minimum acceptable trial length (in samples) 
    MIN_ALLOWED = 10000; % << adjust this to your sampling rate 
    % Keep only trials that meet this requirement 
    valid_idx = TrialLength >= MIN_ALLOWED; 
    if sum(valid_idx) == 0 
        error('No trials longer than MIN_ALLOWED = %d samples.', MIN_ALLOWED); 
    end 
    % Apply filtering 
    grouped_SE = grouped_SE(valid_idx); 
    PAM_levels = PAM_levels(valid_idx); 
    TrialLength = TrialLength(valid_idx); 
    % Nowcompute the real minimum 
    minTriallength = min(TrialLength); 
    fprintf('Minimum length = %d\n', minTriallength); 
    
    % 6) cut all to same length 
    same_len_trials = grouped_SE; 
    nTrials = numel(grouped_SE);
    for i = 1:nTrials 
    same_len_trials{i} = [grouped_SE{i}(1), grouped_SE{i}(1) + minTriallength]; 
    end 
    
    % 7) extract EEG: trials x channels x time 
    nChan = size(ica_act, 1); 
    fprintf('nTrials = %d\n', nTrials);
    ica_data = zeros(nTrials, nChan, minTriallength+1); 
    for i = 1:nTrials 
        ica_data(i, :, :) = ica_act(:, same_len_trials{i}(1):same_len_trials{i}(2)); 
    end 

end
