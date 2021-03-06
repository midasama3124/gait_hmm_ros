function [ output_args ] = create_anfis_classifier( input_file, label_file, normal_file, k )
    if(k==0)
        k=7
    end
    
    if(size(strfind(input_file, 'subject1'))~=0)
        remove = 1973
    elseif (size(strfind(input_file, 'subject2'))~=0)
        remove = 1805
    elseif(size(strfind(input_file, 'subject3'))~=0)
        remove = 2187
    end
    assignin('base','k', k)
    workspace_file = ['~/full_data/trained_wss/',input_file]
    input_file = ['~/full_data/',input_file]
    label_file
    normal_file
    full_data = load(input_file);
    full_data = full_data.data;
    
    full_data = full_data(1:end-remove, :);
    full_labels = load(label_file);
    full_labels = double(full_labels.labels(1:end-remove));
    full_labels = full_labels';
    
    normal_labels = load(normal_file);
    normal_labels = normal_labels.norm_labels(1:end-remove);
    normal_labels = normal_labels';
    binary_labels = normal_labels;
    binary_labels(binary_labels~=0) = 1;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    full_data = horzcat(full_data, full_labels);
    full_labels = double(normal_labels);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    assignin('base', 'full_data', full_data);
    assignin('base', 'full_labels', full_labels);
    assignin('base', 'normal_labels', normal_labels);
    assignin('base', 'binary_labels', binary_labels);
    type = 'holdout'
    if strcmp(type,'kfold')
        CVO = cvpartition(full_labels, 'k', k);
        assignin('base', 'CVO', CVO);
        err = zeros(CVO.NumTestSets, 1);
        trIdx = CVO.training(1);
        assignin('base', 'trIdx', trIdx);
        teIdx = CVO.test(1);
        assignin('base', 'teIdx', teIdx);
        
        chkIn = full_data(CVO.training(2),:);
        chkCl = full_labels(CVO.test(2),:);
        
        assignin('base', 'chkIn', chkIn);
        assignin('base', 'chkCl', chkCl);
        
        dispOpt = ones(1,4);
        trnOpt = {500, 0.01, 0.01, 0.9, 1.1}
        
        tr_in = full_data(trIdx,:);
        tr_cl = full_labels(trIdx,:);
        
        assignin('base', 'tr_in', tr_in);
        assignin('base', 'tr_cl', tr_cl);
        
        te_in = full_data(teIdx,:);
        te_cl = full_labels(teIdx,:);
        
        assignin('base', 'te_in', te_in);
        assignin('base', 'te_cl', te_cl);
        
        tr_full = [tr_in tr_cl];
        te_full = [te_in te_cl];
    else
        CVO = cvpartition(full_labels, 'HoldOut', 0.4);
        assignin('base', 'CVO', CVO);
        trIdx = CVO.training;
        assignin('base', 'trIdx', trIdx);
        teIdx = CVO.test;
        assignin('base', 'teIdx', teIdx);
        
        CV02 = 0;
        val_in = 0;
        val_cl = 0;
        valIdx = 0;
        testIdxFin = 0;
        
        dispOpt = zeros(1,4);
        trnOpt = [100, 0.01, 0.01, 0.9, 1.1]
        
        tr_in = full_data(trIdx,:);
        tr_cl = full_labels(trIdx,:);
        
        assignin('base', 'tr_in', tr_in);
        assignin('base', 'tr_cl', tr_cl);
        
        te_in = full_data(teIdx,:);
        te_cl = full_labels(teIdx,:);
        %%%%%%%%%%%SEPARATE INTO VALIDATION AND TEST%%%%%%%%%%
        CVO2 = cvpartition(te_cl, 'HoldOut', 0.5);
        
        valIdx = CVO2.training;
        testIdxFin = CVO2.test;
        
        val_in = te_in(valIdx, :);
        val_cl = te_cl(valIdx, :);
        
        te_in = te_in(testIdxFin, :);
        te_cl = te_cl(testIdxFin, :);
        
        assignin('base', 'val_in', val_in);
        assignin('base', 'val_cl', val_cl);
        %%%%%%%%%%%%% ENDS HERE %%%%%%%%%%%%%%%%%%%%%%
        
        assignin('base', 'te_in', te_in);
        assignin('base', 'te_cl', te_cl);
        
        tr_full = [tr_in tr_cl];
        te_full = [te_in te_cl];
    end
    
    d = size(full_data);
    radii = ones(1,d(2)+1)*0.2;
    radii(1, end) = 1;
    assignin('base', 'radii', radii);

    xBounds = zeros(2, length(full_data(1,:))+1);
    for n = 1:length(full_data(1,:))
        xBounds(1,n) = min(full_data(:,n));
        xBounds(2,n) = max(full_data(:,n));
    end
    xBounds(1,length(full_data(1,:))+1)=0;
    xBounds(2,length(full_data(1,:))+1)=1;
    assignin('base', 'xBounds', xBounds);
    
    disp('FIS2 GEN')
    gf2 = genfis2(tr_in, tr_cl, radii, xBounds);
    assignin('base', 'gf2', gf2);

    disp('Anfis start ')
    error = 0;
    stepsize = 0;
    chkFis = 0;
    chkErr = 0;
    [an1, error, stepsize, chkFis, chkErr] = anfis([tr_in tr_cl], gf2, trnOpt, dispOpt, [val_in val_cl]);
    size(tr_in)
    size(val_in)
    size(te_in)
    assignin('base', 'an1', an1);
    assignin('base', 'error', error);
    assignin('base', 'stepsize', stepsize);
    assignin('base', 'chkFis', chkFis);
    assignin('base', 'chkErr', chkErr);
    disp('evalfis start ')
    output = evalfis(te_in, an1);
    assignin('base', 'output', output);
    
    max_a = max(output,[],1);
    min_a = min(output,[],1);
    [row,col] = size(output);
    output_norm=((repmat(max_a,row,1)-output)./repmat(max_a-min_a,row,1));
    assignin('base', 'output_norm', output_norm);
    name = [workspace_file(1:end-4), '_workspace.mat']
    save(name, 'an1', 'error', 'stepsize', 'chkFis', 'chkErr',...
    'binary_labels', 'val_cl', 'val_in', 'CVO', 'CVO2','full_data',...
    'full_labels', 'gf2', 'normal_labels', 'output', 'output_norm', ...
    'radii', 'te_cl', 'te_in', 'teIdx', 'tr_cl', 'tr_in', 'trIdx', 'xBounds', 'k')
end

