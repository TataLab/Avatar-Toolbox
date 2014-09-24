function [ trainingBins, rawData] = trainingProper(trainLen, setDelay, Fs,minFreq,maxFreq)
%This function will train a user by simply making them switch between
%opening their eyes and closing their eyes every two seconds. It then
%calculates the change in eeg activity from one state to the other to be
%used later.
global memFile;
numChans=1;
frameData=zeros(numChans, 256);

Fs2 = 1000;      %# Samples per second
toneFreq = 500;  %# Tone frequency, in Hertz
nSeconds = 0.5;   %# Duration of the sound
y = sin(linspace(0, nSeconds*toneFreq*2*pi, round(nSeconds*Fs2)));
%create initial sound to prepare the audio hardware if this is not
%performed the computer has a hicup the first time the sound is created
%while recording eeg data and it can corrupt an eeg frame.
sound(y,Fs2);
%raw data from each second of eeg activity. 
x=[];
%The mean of alpha activity stored over each second. 
rawData=zeros(trainLen*16,256);
trainingVal=zeros(1,trainLen*16);
trainOpen=zeros(1,trainLen*7);
trainClose=zeros(1,trainLen*7);

%initial loop to ignore the first samples until we are past the setDelay.
k=1;
while(k<=setDelay)
    memFile.Data.d(1:numChans,:)
if(memFile.Data.d(1:numChans,:)~=frameData)
k=k+1;
frameData=memFile.Data.d(1:numChans,:);
end
end

%build the training bins
trainingBins=zeros(trainLen*14,4);

track=1;
tracko=1;
trackc=1;
%Enter the training loop that will switch states and add the alpha activity
%over each recorded second to the vector trainingVal.
k=1;
while k<=trainLen
l=1;
while l<=16
if(memFile.Data.d(1:numChans,:)~=frameData)
l=l+1;
frameData=memFile.Data.d(1:numChans,:);



    location=(k-1)*16+l;
    
x=frameData;
    rawData(location,1:end)=x;
    
   if(l>2) 
   [temp,freqs]=periodogram(x,[],[],500,'one-sided');
   pGrams=temp;
    

%define some frequency bins
delta=[find(freqs>=1,1,'first') find(freqs>=4,1,'first')];
theta=[find(freqs>=5,1,'first') find(freqs>=9,1,'first')];
alpha=[find(freqs>=10,1,'first') find(freqs>=14,1,'first')];
beta=[find(freqs>=15,1,'first') find(freqs>=25,1,'first')];




    trainingBins(track,1)=mean(pGrams(delta(1):delta(2)));
    trainingBins(track,2)=mean(pGrams(theta(1):theta(2)));
    trainingBins(track,3)=mean(pGrams(alpha(1):alpha(2)));
    trainingBins(track,4)=mean(pGrams(beta(1):beta(2)));

    track=track+1;
   end
    end
   end
k=k+1;
    sound(y,Fs2);
    end
   

end



