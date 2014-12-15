 %a function to perform face recognition on 100 testing data on version 2
%model i.e. only identity hidden variables.
function pr_models=faceRecognitionVersion3PatchesDemo(k,patchLibrary)


libDir='C:\PhD Research\Code\Mosaicfaces\Appearance Model\Appearance Model on data with diff illumination\'; 


%load training set to know the find the trainingsize
load ([libDir 'newLightPatchTrainingSets8.mat']);
trainingID=size(trainPatch,2);
%Load the testing set 
load ([libDir 'newLightPatchTestingSets8.mat']);
imageIDTest=imageID;
 
%Load the dataIDmatrix
%load ([sourceDir 'enhancedSets.mat']);
% load([libDir2 'appearanceSetsTest.mat']);
% imageIDTest=imageIDTestApp;

%find number of total patches in each image
n_Patch=size(testPatch,1);
fix_mean_flag=0;
%load the size of the image and number of the patches 
load ([libDir 'patchInfo8.mat'], 'nX','nY','nZ','patchNum');

%get the dimensions of each patch
patch_sizeX=nX/patchNum;
patch_sizeY=nY/patchNum;

draw_flag1=0;
draw_flag2=0;
%pr_models=zeros(n_Patch,100);
pCount=0;
%select patch region and do model selection for each patch region
for(cPatch=1:40)

    if~(mod(cPatch,8))

    elseif ~((cPatch==28)|(cPatch==34))
        pCount=pCount+1;
        %collect the testing set for
        testingSet=squeeze(testPatch(cPatch,:,:));


        gaussEst=patchLibrary{cPatch};

        %select testing set
        for(cPerson=1:size(imageIDTest,2))
            indices=find(imageIDTest(:,cPerson));
            indices=indices-trainingID;
            l=length(indices);
            gallery(:,cPerson)=testingSet(indices(1),:);
            probe(:,cPerson)=testingSet(indices(l-1),:);

        end

        %initialization of variables
        n_model=size(gallery,2);
        n_data=size(gallery,2);
        postModel=ones(1,n_model);

        %save ([libDir 'galleryProbe2Patch' num2str(cPatch) '.mat'],'gallery','probe');
        %load ([testDir 'galleryProbe.mat'],'gallery','probe');

        n_correct=0;
        count=1;

        %find all single terms
        for (m=1:n_model)
            S(m)=version3FindSingleTermsTDist(gallery(:,m),gaussEst);
        end

        %select the probe image
        XP=probe(:,k);
        X=gallery(:,k);
        if(draw_flag1)
            close all;
            if(fix_mean_flag)
                l=squeeze(X);
                gaussEst(1,1).mean=l;
                lp=squeeze(XP);
                gaussEst(1,2).mean=lp;
            end
            [N_IND N_APP]=size(gaussEst);
            %find the most likeliy patch in the library that explain
            %the probe and the gallery image
            %[mostLikelyLibPatch dataLogLike]=findMostLikelyLibPatch(XP,cPatch);
            %Find a common cause for gallery and probe
            [mostLikelyHi,logLikeGivenHi,mostLikeLyAppX,mostLikeLyAppXP]=findCommonCause(X',XP',gaussEst);
            reconsPatch{cPatch}=gaussEst(mostLikelyHi,mostLikeLyAppX).mean;
            %plot the gallery patch
            subplot(2,2,1);imshow(reshape(uint8(gallery(:,k)),patch_sizeX,patch_sizeY,nZ));
            xlabel('gallery');
            %plot the probe patch
            subplot(2,2,2); imshow(reshape(uint8(XP),patch_sizeX,patch_sizeY,nZ));
            xlabel('probe');
            %plot the the most likely library patch for gallery
            subplot(2,2,3); imshow(reshape(uint8(gaussEst(mostLikelyHi,mostLikeLyAppX).mean),patch_sizeX,patch_sizeY,nZ));
            xlabel(['ML gallery' num2str(mostLikelyHi) num2str(mostLikeLyAppX)]);

            %plot the the most likely library patch for rpobe
            subplot(2,2,4); imshow(reshape(uint8(gaussEst(mostLikelyHi,mostLikeLyAppXP).mean),patch_sizeX,patch_sizeY,nZ));
            xlabel(['ML probe' num2str(mostLikelyHi) num2str(mostLikeLyAppXP)]);
            drawnow;

            pCount=0;
            figure('name',['Patch ' num2str(cPatch) ' Librari Ind 1-4']);
            for (cInd=1:N_IND/2)
                for (cApp=1:N_APP)
                    pCount=pCount+1;
                    subplot(4,2, pCount);
                    imshow(uint8(reshape(gaussEst(cInd,cApp).mean,9 ,9 ,3)));

                    %fileName=[destinationDir ['Patch' num2str(cPatch) 'LibrariInd1-4.jpg']];
                    %print ('-djpeg',fileName);

                end

            end

            figure('name',['Patch ' num2str(cPatch) ' Librari Ind 5-8']);

            pCount=0;
            for (cInd=N_IND/2+1:N_IND)
                for (cApp=1:N_APP)
                    pCount=pCount+1;
                    subplot(4,2, pCount);
                    imshow(uint8(reshape(gaussEst(cInd,cApp).mean,9 ,9 ,3)));

                    %fileName=[destinationDir ['newLightPatch8LibraryVersion3G82Patch' num2str(cPatch) 'LibrariInd5-8.jpg']];
                    %print ('-djpeg',fileName);

                end

            end
            drawnow;
        end



        %calculate the likelihodd of the models given the probe
        for(i=1:n_model)
            pr_models(pCount,i)=version3GetProbModelTDist(gallery, XP,gaussEst,S,i);
        end

        %find the posterior probability of the model as the product of
        %thepoeteriors of all patches
        %postModel=postModel+pr_models(cPatch,:);
        if(draw_flag2)
            %plot the likelihood of the models given this pathces
            subplot(3,2,cPatch);plot(pr_models(cPatch,:),'r-');
            hold on;
            drawnow;
        end
        %end

    end
    % [X,Y]=meshgrid([1:n_Patch],[1:n_model]);
    % mesh(X,Y,pr_models);
    % plot(pr_models)

    %Rescaling the probabilities
    maxPrm=max(postModel(:));
    postModel=postModel-maxPrm;

    postModel=exp(postModel);

    posterior_models=postModel/sum(postModel);
    %Finding the estimated identity/class/index


    %save([libDir 'recognitionRatePatch2.mat'],'n_correct','postModel');

    if(draw_flag2)
        %plot the posterior probabilities of all models
        hold on;
        subplot(3,2,5:6);plot(posterior_models,'r-');
    end
    %draw the reconstructed image
    % if(draw_flag1)
    %     sourceDir='C:\PhD Research\Face Recognition\Probabilistic FR\Enhanced Images\';
    %     load ([sourceDir 'enhancedSets.mat']);
    %
    %     %plot reconstructed face image
    %     figure;
    %     reconX=buildImage(patchNum,reconsPatch,patch_sizeX,patch_sizeY,nZ);
    %     indices=find(imageIDTest(:,k));
    %     faceXp=testingSet(indices(2),:);
    %     faceG=testingSet(indices(1),:);
    %     subplot(2,2,1); imshow(reshape(uint8(faceG),70,70,3));
    %     title('Gallery Image');
    %     hold on;
    %     subplot(2,2,2); imshow(reshape(uint8(faceXp),70,70,3));
    %     title('Probe Image');
    %     subplot(2,2,3:4); imshow(uint8(reconX));
    %     title('Reconstrcuted Image');
    %     drawnow;
    % end

end

end
