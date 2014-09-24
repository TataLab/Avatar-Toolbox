%AnalyzeThese is a "worksheet" sort of script meant to crunch through
%multisubject data sets.  You can comment out sections you don't want to
%execute

%any parameters that we might want we'll put into a struct called W.  That
%will help keep the workspace clear

%a few simplifying assumptions:

%one simplifying assumption we make here is that each subject's eegD.data
%and eegD.time matrices are the same size...that is, their session
%durations were the same.  This assumption allows us to use data arrays
%instead of cell arrays which makes parrallelization easier.

%another simplifying assumption is that we already know the size of the
%eegD.data matrix (how many channels and how many samples).  You can open
%one up and check it if you have to.


%it works on a folder with subjects in subfolders like this:
%
%subjects
 %  - subject1
 %  - subject2
 %  - .
 %  - .
 %  - .
 %  - kNumSubjects
 
 %the resulting data matrix will be a subjects x chanels x samples array

%************reading data******************%

dataPath = '/Users/Matthew/Documents/MATLAB/Simple Auditory ERP/Joshs data set/subjects/';  %this part you have to change to match your directory tree

subjectNames = {  
                                    
                                    'subject3/'
                                    'subject4/'
                                    
                                   };
                                     
  dataFileName = 'datasession.mat';
                               
  %you might have recorded all channels but we are only intersted in a
  %subset so we can trim the data set here to make filtering faster
  W.chans = [1 4 8];  % you might not want to filter all the channels so here's a list of what you want filtered
  LChans = length(W.chans);
                               
  %build the matrix of mutisubject data, adjust parameters as needed                                  
 
  W.kNumSubjects = length(subjectNames);
  W.kNumChannels = length(W.chans);
  W.kNumSamples = 510000;
  
  %multiD is the multisubject version of eegD
  multiD.data = zeros(W.kNumSubjects,W.kNumChannels, W.kNumSamples);
  multiD.time = zeros(W.kNumSubjects,W.kNumSamples);

  for i=1:W.kNumSubjects
      tempMatrix = open([dataPath subjectNames{i,1} dataFileName]);  %concatenate strings to build the path of the data files
        
      %here's a crude check to handle sessions of different durations
      %(shouldn't happen) 
      if size(tempMatrix.eegD.data,2) > W.kNumSamples
          dif = size(tempMatrix.eegD.data,2) - W.kNumSamples;
          tempMatrix.eegD.data = tempMatrix.eegD.data(:,1:W.kNumSamples);
          tempMatrix.eegD.time = tempMatrix.eegD.time(1,1:W.kNumSamples);
          display(['warning: we have to trim ' int2str(dif) ' samples off the end of subject' int2str(i)]);
      end
      
      %only pull out channels we want, note that the order will be
      %preserved but now the position in the matrix is no longer also the
      %channel number
      
      for j=1:W.kNumChannels
            multiD.data(i,j,:) = tempMatrix.eegD.data(W.chans(j),:);
      end
      
      multiD.time(i,:) = tempMatrix.eegD.time;
  end

  clear tempMatrix;
  
  
  
  %************done reading data*************************%
  
  
  
  %************filtering data ******************************%
  
  %probably want to highpass then lowpass your data
  %note eegfilt can do this in one step as a band pass, but it seems to
  %fail from time to time and the recommended workaround is to do it in
  %steps anyway.
  
  %the EEGLab function eegfilt will use MATLAB's filtfilt() function

  %some pre-loop shennanigans to optimize for parfor()...usually better
  %this way
  tempFilteredData = zeros(size(multiD.data));  %to hold the filtered data
  tempUnfilteredData = multiD.data;
  tempNumChans = W.kNumChannels;
  T=tic;  %for timing the performance
  
  %first highpass then lowpass
  parfor i=1:W.kNumSubjects
      display(['filtering data for subject' int2str(i)]);
      for j=1:tempNumChans
          display(['filtering signal ' int2str(j)]);
          tempFilteredData(i,j,:) = eegfilt(tempUnfilteredData(i,j,:),500,0.5,0);
          tempFilteredData(i,j,:) = eegfilt(tempFilteredData(i,j,:),500,0,20);
      end
  end
 

  %now put the data back together 
  multiD.filteredData = tempFilteredData;
  
  clear tempFilteredData;
  clear tempUnfilteredData;
  clear tempNumChans;
  
  display(['done filtering.  That took ' num2str(toc(T)) ' seconds']);
  clear T
  %*************done filtering****************%
  
  
  
  
  %**************get the events data and extract epochs********
  
  
  %we'll make subject x events arrays for each kind of event
  %then we'll make subject x event x samples arrays of epochs
  %then the grand average erp is just collapsing the entire epoch array
  %across dims 1 and 2
  
  W.kEpochLengthSamples = 600;
  W.kBaselineStart = -300; %in samples
  
  W.kNumTrials = 15;
  W.kNumTargets = W.kNumTrials * 5;
  W.kNumNontargets = W.kNumTrials * 10;
  
  ERPs.targetEvents = zeros(W.kNumSubjects,W.kNumTargets);
  ERPs.nontargetEvents = zeros(W.kNumSubjects,W.kNumNontargets);
  
  ERPs.targetEpochs = zeros(W.kNumSubjects,W.kNumTargets,W.kEpochLengthSamples);
  ERPs.nontargetEpochs = zeros(W.kNumSubjects,W.kNumNontargets,W.kEpochLengthSamples);
  
  for i=1:W.kNumSubjects
      
      ERPs.targetEvents(i,:) = ImportEvents([dataPath subjectNames{i,1} 'targetEvents.tim'],W.kNumTargets);
      ERPs.nontargetEvents(i,:) = ImportEvents([dataPath subjectNames{i,1} 'nontargetEvents.tim'],W.kNumNontargets);

      
     
  end
  
  %*********done extracting and setting up epochs**************%
  
  
%******make and plot some ERPs*****

ERPs.targetERPs = zeros(W.kNumSubjects,W.kNumChannels,W.kEpochLengthSamples);
ERPs.nontargetERPs = zeros(W.kNumSubjects,W.kNumChannels,W.kEpochLengthSamples);
ERPs.targetGoodEvents=cell(W.kNumSubjects,1); %these must be cell arrays because the different rows will have different numbers of events
ERPs.nontargetGoodEvents = cell(W.kNumSubjects,1);

for i=1:W.kNumSubjects
  display(['computing ERP for subject ' int2str(i)]);
  [ERPs.targetERPs(i,:,:),ERPs.time,ERPs.targetGoodEvents{i}] = MakeAnERP(multiD.filteredData(i,:,:),multiD.time(i,:),ERPs.targetEvents(i,:),W.kNumChannels,W.kEpochLengthSamples,1,3);
  [ERPs.nontargetERPs(i,:,:),~,ERPs.nontargetGoodEvents{i}] = MakeAnERP(multiD.filteredData(i,:,:),multiD.time(i,:),ERPs.nontargetEvents(i,:),W.kNumChannels,W.kEpochLengthSamples,1,3);
end
  
  ERPs.targetGrandAverage = squeeze(mean(ERPs.targetERPs,1));
  ERPs.nontargetGrandAverage = squeeze(mean(ERPs.nontargetERPs,1));

%   figure(1);
%   plot(ERPs.targetGrandAverage(1,:));
%   hold on;
  %plot(ERPs.nontargetGrandAverage(1,:),'red');
  
 %******************************** 
  
 
 %*******simple check of periodograms pre- and post-stimulus
 
 for i=1:W.kNumSubjects
        ERPs.targetEpochs(i,:,:) = ExtractEpochs(multiD.filteredData(i,:,:),multiD.time(i,:),ERPs.targetEvents(i,:),1,W.kEpochLengthSamples,W.kBaselineStart);
        ERPs.nontargetEpochs(i,:,:) = ExtractEpochs(multiD.filteredData(i,:,:), multiD.time(i,:),ERPs.nontargetEvents(i,:),1,W.kEpochLengthSamples,W.kBaselineStart);    
 end
 
 
 
 
  
   %clean up variables from the workspace that we don't need
  %pack up some that we might into a convenient struct
 
  
  clear LChans
  clear dataFileName
  clear dataPath
  clear dif
  clear i
  clear j
  clear subjectNames
  
  
  
  