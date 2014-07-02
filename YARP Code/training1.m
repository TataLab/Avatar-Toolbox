function [ avOpen, avClose, drift, trainingVal ] = training1(trainLen, setDelay, port, b, Fs)
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
trainingVal=[];

%initial loop to ignore the first samples until we are past the setDelay.
for k=1:setDelay
    port.read(b);
end

%Enter the training loop that will switch states and add the alpha activity
%over each recorded second to the vector trainingVal.
for k=1:trainLen
    ok=port.read(b);
    x=str2num(char(b.toString()));
    freq = 0:Fs/length(x):Fs/2;
    xdft = fft(x);
    xdft=abs(xdft);
    % I only need to search 1/2 of xdft for the max because x is real-valued
    xdft=xdft(1:length(x)/2+1);
        
    desired1 = find(freq <= 14,1,'last');
    desired2 = find(freq >=10,1,'first');
    trainingVal(k)=mean(xdft(desired2:desired1));
    if mod(k,2) == 0
        sound(y,Fs2);
    end
end

changeClosed=[];
changeOpen=[];
tracker=1;

%The following two loops will use the data stored in the vector trainingVal
%and calculate the average change in alpha activity between switching of
%state from open to closed, and closed to open. 
for i=2:4:trainLen-2
    totClose=trainingVal(i+1)-trainingVal(i);
    drift=trainingVal(i+2)-trainingVal(i+1);
    changeClosed(tracker)=totClose-drift;
    tracker=tracker+1;
end
tracker=1;
for i=4:4:trainLen-2
    totOpen=trainingVal(i+1)-trainingVal(i);
    drift=trainingVal(i+2)-trainingVal(i+1);
    changeOpen(tracker)=totOpen-drift;
    tracker=tracker+1;
end

avOpen=mean(changeOpen);
avClose=mean(changeClosed);

drift=trainingVal(end)-trainingVal(end-1);


end

