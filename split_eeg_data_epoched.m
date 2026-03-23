function [X_train, Y_train, X_val, Y_val, X_test, Y_test] = split_eeg_data_epoched(X, Y, trainRatio, valRatio)
% ... (Documentation remains the same)

    nTrials = size(X, 1);
    % Ensure labels are a column vector
    Y = Y(:);
    
    % Shuffle the data
    perm = randperm(nTrials);
    % **IMPORTANT: Use a comma-colon for all subsequent dimensions**
    X = X(perm,:, :); 
    Y = Y(perm, :);
    
    % Split sizes
    nTrain = floor(trainRatio * nTrials);
    nVal   = floor(valRatio * nTrials);
    nTest  = nTrials - nTrain - nVal;
    
    % Split indices
    iTrain = 1:nTrain;
    iVal   = nTrain+1 : nTrain+nVal;
    iTest  = nTrain+nVal+1 : nTrials;
    
    % Assign outputs
    % Using :, : (or just :, :) ensures all remaining dimensions are included.
    X_train = X(iTrain, :, :);
    Y_train = Y(iTrain, :);
    
    X_val = X(iVal, :, :);
    Y_val = Y(iVal, :);
    
    X_test = X(iTest, :, :);
    Y_test = Y(iTest, :);
end