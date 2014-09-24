

%Load the appropriate Avatar device settings. 
SetEEGConfig_series4000;

%set up memmap
frameSize=256;
fileName='./eegData.dat';

fixedLag=10; %a few extra samples to lag behind real time, often this can be set to zero, but a bit of know lag is better than unknown lag

%memory map that file
global memFile;
memFile=memmapfile(fileName,'format',{'double' [EEG_Config.numChans+1 frameSize] 'd'}, 'writable',false);  %the +1 is the timestamps channel.  Mac OS and Unix let you memmory map more than one file for writting.  I think Windows complains about this.



%Set the variable Fs to the sampling rate in the device's config file. 
Fs = EEG_Config.SRate;
%Set the length of time you wish to train the user in seconds. 
trainLen=20; %must be even number
%Set the amount of time in seconds that will be ignored at the start of the
%training session to allow the device to compose itself. Note this will be
%added onto the time trainLen but will simply be ignored so that the all
%the hardware has time to compose itself.
setDelay=10;


%This variable holds 0 if we wish to continue measuring if the eyes are
%closed or open but will hold 1 if we wish to exit that loop. 
done=0;
%Set this variable to the number of channels enabled in the config file. 
Channels=EEG_Config.numChans;


%disp('Going to open port /matlab/read');
%port.open('/matlab/read');
%disp('Going to connect ports');
%if net.connect('/matlab/write', '/matlab/read')
 %   disp('connection established');
%else
 %   disp('error in connection');
%end


disp('The program closes when ''quit'' is received');

disp(['Keep eyes open to start the test. There will be an initial beep, then every time you hear a']);
disp(['beep alternate which state your eyes are in (if open then close them, if closed then open them)']);
min=10;
max=14;

%[rawData, trainingVal, trainOpen, trainClose]=training(trainLen,setDelay,port,b,Fs,min,max);

[trainingBins, rawData]=trainingProper(trainLen,setDelay,Fs,min,max);

lables={'open';'open';'open';'open';'open';'open';'open';'open';'open';'open';'open';'open';'open';'open';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed';'closed'};
lables=repmat(lables,trainLen/2,1);

%construct a KNN classifier
display('constructing a classifier based on the training data');
model=ClassificationKNN.fit(trainingBins,lables);

%adjust the number of nearest neighbors
model.NumNeighbors=4;

%check the model
rloss=resubLoss(model);
cvmdl=crossval(model);
kloss=kfoldLoss(cvmdl);


done=SessionProper(Fs,model);



port.close

