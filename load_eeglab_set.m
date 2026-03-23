function EEG = load_eeglab_set(setName, folder)
    EEG = pop_loadset('filename', setName, 'filepath', folder);
end