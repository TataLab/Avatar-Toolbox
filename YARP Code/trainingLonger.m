function [ rawData, trainingVal, trainOpen, trainClose ] = training(trainLen, setDelay, port, b, Fs,minFreq,maxFreq)
%This function will train a user by simply making them switch between
%opening their eyes and closing their eyes every two seconds. It then
%calculates the change in eeg activity from one state to the other to be
%used later. 

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
for k=1:setDelay
    port.read(b);
end

track=1;
tracko=1;
trackc=1;
%Enter the training loop that will switch states and add the alpha activity
%over each recorded second to the vector trainingVal.
for k=1:trainLen
    for l=1:16
    ok=port.read(b);
    
    x=str2num(char(b.toString()));
    rawData((k-1)*16+l,1:end)=x;
    
    
   [data,freq]=periodogram(x,[],Fs);
  
    desired1 = find(freq >= (minFreq/(Fs/2))*pi,1,'first');
    desired2 = find(freq <=(maxFreq/(Fs/2))*pi,1,'last');
    tempVal= mean(data(desired1:desired2)); 
   if(l>=2 && l<=15)
   if (mod(k,2))
        trainOpen(tracko)=tempVal;
        tracko=tracko+1;
   else
        trainClose(trackc)=tempVal;
        trackc=trackc+1;
   end
   end
   
    
    trainingVal(track)=tempVal;
    track=track+1;
    end
    sound(y,Fs2);
    end
   

end



