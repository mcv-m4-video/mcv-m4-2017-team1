%Highway 1050 - 1350
%Fall 1460 - 1560
%Traffic 950 - 1050
close all
clear all

video=1;
tic
%Paths to the input images and their groundtruth
sequencePath = {'datasets/highway/input/' 'datasets/traffic/input/' 'datasets/fall/input/'} ;
groundtruthPath = {'datasets/highway/groundtruth/' 'datasets/traffic/groundtruth/' 'datasets/fall/groundtruth/'};
%Initial and final frame of the sequence
iniFrame = [1050 950 1460];
endFrame = [1350 1050 1560];

for seq=1:3
    disp(['Sequence ' num2str(seq)])
    %Train the background model with the first half of the sequence
    [means, deviations] = trainBackgroundModelAllPix(char(sequencePath(seq)), char(groundtruthPath(seq)), iniFrame(seq), (endFrame(seq)-iniFrame(seq))/2);
    na_means=means;
    na_deviations=deviations;
    
    [meansrgb, deviationsrgb] = trainBackgroundModelColor(char(sequencePath(seq)), char(groundtruthPath(seq)), iniFrame(seq), (endFrame(seq)-iniFrame(seq))/2);
    meansrgI = meansrgb;
    meansrgI(:,:,1) = meansrgI(:,:,1)./(meansrgI(:,:,1)+meansrgI(:,:,2)+meansrgI(:,:,3));
    meansrgI(:,:,2) = meansrgI(:,:,2)./(meansrgI(:,:,1)+meansrgI(:,:,2)+meansrgI(:,:,3));
    meansrgI(:,:,3) = (meansrgI(:,:,1)+meansrgI(:,:,2)+meansrgI(:,:,3));
    
    
    %Define the range of alpha
    %Define the range of rho
    if seq==1
        rho=0.22;
        alpha=0:30;
    elseif seq==2
        rho=0.22;
        alpha=0:30;
    elseif seq==3
        rho=0.11;
        alpha=0:30;
    end
    
    %Allocate memory for variables
    numAlphas = size(alpha,2);
    numRhos= size(rho,2);
    
    precision = zeros(1,numAlphas); recall = zeros(1,numAlphas);
    accuracy = zeros(1,numAlphas); FMeasure = zeros(1,numAlphas);
    
    TPTotal=zeros(1,numAlphas);FPTotal=zeros(1,numAlphas);
    TNTotal=zeros(1,numAlphas);FNTotal=zeros(1,numAlphas);
    
    %Get the information of the input and groundtruth images
    FilesInput = dir(char(strcat(sequencePath(seq), '*jpg')));
    FilesGroundtruth = dir(char(strcat(groundtruthPath(seq), '*png')));
    
    % k is used as an index to store information, in case alpha has 0, decimal or
    %negative values
    k=0;
    l=0;
    
    %Chose type of SE
    %SE = strel('square',10); %5=width
    %SE = strel('square',5);
    %SE = strel('square',20);
    %SE = strel('disk',5); %5=Radius
    %SE = strel('disk',10);
    %SE = strel('disk',20);
    %SE = strel('diamond',10 ); %R=distance from the SE to the points of the diamond
    SE = strel('line',20,30);  %len es llargada i deg els graus
    
    %Chose Connectivity
    conn=4;
    %conn=8
    
    for al = alpha
        deviations=na_deviations;
        means=na_means;
        k=k+1;
        %Detect foreground objects in the second half of the sequence
        for i = iniFrame(seq)+(endFrame(seq)-iniFrame(seq))/2+1:endFrame(seq)
            %Read an image and convert it to grayscale
            image = imread(strcat(char(sequencePath(seq)),FilesInput(i).name));
            grayscale = double(rgb2gray(image));
            %Read the groundtruth image
            groundtruth = readGroundtruth(char(strcat(groundtruthPath(seq),FilesGroundtruth(i).name)));
            %%%%% --> better results if we count the hard shadows as foreground
            %%%%% groundtruth = double(imread(strcat(groundtruthPath,FilesGroundtruth(i).name))) > 169;
            old_means=means;
            old_deviations=deviations;
            
            %Detect foreground objects
            [detection,means,deviations] = detectForeground_adaptive(grayscale, means, deviations,al,rho);
            
            %Connectivity
            detection=imfill(detection,conn,'holes');
            
            %Choose Morph Operator
            %detection=imclose(detection,SE);   %closing
            detection=imopen(detection,SE);    %opening
            %detection=imdilate(detection,SE);   %dilation
            %detection=imerode(detection,SE);   %erosion
            
            detection = detectShadows(image,detection, meansrgI);
            
            
            
            %Compute the performance of the detector for the whole sequence
            [TP,FP,TN,FN] = computePerformance(groundtruth, detection);
            TPTotal(k)=TPTotal(k)+TP;
            FPTotal(k)=FPTotal(k)+FP;
            TNTotal(k)=TNTotal(k)+TN;
            FNTotal(k)=FNTotal(k)+FN;
            
            %Show the output of the detector
            %figure(2)
            %imshow(detection)
        end
        %Compute the performance of the detector for the whole sequence
        [precision(k),recall(k),accuracy(k),FMeasure(k)] = computeMetrics(TPTotal(k),FPTotal(k),TNTotal(k),FNTotal(k));
        
        vec(seq,k,1)=precision(k);
        vec(seq,k,2)=recall(k);
        vec(seq,k,3)=accuracy(k);
        vec(seq,k,4)=FMeasure(k);
        
        
    end
end

toc
%Precision
figure();
for seq=1:numel(iniFrame)
    plot(alpha, vec(seq,:,1))
    hold on
end
hold off
title('Precision for the 3 sequences'); xlabel('Alpha'); ylabel('Precision')
legend('Highway','Traffic','Fall'); ylim([0 1])

%Recall
figure();
for seq=1:numel(iniFrame)
    plot(alpha, vec(seq,:,2))
    hold on
end
hold off
title('Recall for the 3 sequences'); xlabel('Alpha'); ylabel('Recall')
legend('Highway','Traffic','Fall'); ylim([0 1])

%Precision-Recall
figure()
for seq=1:numel(iniFrame)
    plot(vec(seq,:,2),vec(seq,:,1))
    hold on
end
hold off
title('P-R curve for the 3 sequences'); xlabel('Recall'); ylabel('Precision')
legend('Highway','Traffic','Fall'); axis([0 1 0 1])

%F Measure
figure();
for seq=1:numel(iniFrame)
    plot(alpha, vec(seq,:,4))
    hold on;
end
hold off;
title('Fmeasure for the 3 sequences'); xlabel('Alpha'); ylabel('Fmeasure')
legend('Highway','Traffic','Fall'); ylim([0 1])

for seq=1:3
    [F1,alphas]=max(vec(seq,:,4));
    disp(['F1 & alpha for sequence ' num2str(seq) ': ' num2str(F1) ', ' num2str(alphas-1)] )
end

for seq=1:3
    auc(seq)=trapz(vec(seq,:,1),vec(seq,:,2));
    disp(['AUC for sequence ' num2str(seq) ': ' num2str(auc(seq))] )
end

disp(['Median AUC : ' num2str((sum(auc))/3)] )



