function [eeg_data,  PAM_levels] = build_trials_from_events(EEG) 

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
    midNums   = cellfun(@(p) str2double(p{2}), splitDesc);
    PAM_levels = midNums(1:2:end);
    nonZeroIdx = PAM_levels ~= 0;
    PAM_levels = PAM_levels(nonZeroIdx);

    % 5) compute trial lengths
    nTrials = numel(grouped_SE);
    TrialLength = zeros(1, nTrials);
    for i = 1:nTrials
        TrialLength(i) = diff(grouped_SE{i});
    end
    minTriallength = min(TrialLength);

    % 6) cut all to same length
    same_len_trials = grouped_SE;
    for i = 1:nTrials
        same_len_trials{i} = [grouped_SE{i}(1), grouped_SE{i}(1) + minTriallength];
    end

    % 7) extract EEG: trials x channels x time
    nChan = size(EEG.data, 1);
    eeg_data = zeros(nTrials, nChan, minTriallength+1);
    for i = 1:nTrials
        eeg_data(i, :, :) = EEG.data(:, same_len_trials{i}(1):same_len_trials{i}(2));
    end
end
