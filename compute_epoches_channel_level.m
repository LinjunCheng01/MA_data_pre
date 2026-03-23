% split and raw EEG data into epoches with same length using time warping

subjects     = 8: 18;   % subjects to process
dataDir      = 'C:\Users\11210\Desktop\Masterthesis\data\No_epochs';
saveDir_2    = 'C:\Users\11210\Documents\MATLAB\Masterthesis\eeg_data_epoches';

utilsDir     = 'C:\Users\11210\Documents\MATLAB\Masterthesis\utils';   % folder that contains utils.m

%% === PATHS ===
addpath('C:\Users\11210\Documents\MATLAB\eeglab2025.1.0');
eeglab; %close;

addpath(utilsDir);
%s = 15;

%% === LOOP THROUGH SUBJECTS ===
for s = subjects
    %s = 5;
    fprintf('=== Processing subject %d ===\n', s);
    setFile = sprintf('sub-%d_cleaned_with_ICA.set', s);
    
    %% 1) load .set
    EEG = load_eeglab_set(setFile, dataDir);
    %% 2) build trials + labels
    %[flex_ext] = build_epoches_from_events(EEG);
    [flex_ext] = build_epoches_from_events(EEG);
    %% 3) time warpping
    [EEG_warped, labels_warped] = time_warping_channel(EEG, flex_ext);
    %%
    X_3D = cat(3, EEG_warped{:});
    X = permute(X_3D, [3, 1, 2]);
    %% Convert the 1 x N cell array into a 1 x N double array (vector)
    Y = cell2mat(labels_warped);
    %% 4) split data
    %[X_train, Y_train, X_val, Y_val, X_test, Y_test] =  ...
    %    split_eeg_data_epoched(EEG_final, label_final, 0.7, 0.15);
    %%
    if ~exist(saveDir_2, 'dir')
            mkdir(saveDir_2);
    end
    
    %save(fullfile(saveDir_2, sprintf('eeg_data_epoched_sub_%d.mat', s)), ...
    %     'X_train', 'Y_train', 'X_val', 'Y_val', 'X_test', 'Y_test', '-v7.3');
    save(fullfile(saveDir_2, sprintf('eeg_data_epoched_unsplitted_sub_%d.mat', s)), ...
         'X', 'Y','-v7.3');
end
