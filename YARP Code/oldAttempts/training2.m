function [ avOpen, avClose, trainingVal ] = training2(trainLen, setDelay, port, b, Fs)
%This function will switch between eyes open and closed with longer times
%in each state default 10 seconds. Then it measures the average alpha
%levels in each state instead of the change between states. 

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
%The amount of time in seconds spent in each state. 
timeChange=10;

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
    if mod(k,timeChange) == 0
        sound(y,Fs2);
    end
end


changeClosed=[];
changeOpen=[];
tracker=1;

%In the following two loops we use the eeg data stored in the trainingVal
%vector to determine the average alpha activity when the users eyes are
%open and closed. 
for i=1:10:trainLen-timeChange
    totOpen=sum(trainingVal(i+1:i+timeChange-1));
    %drift=trainingVal(i+1)-trainingVal(i)
    changeOpen(tracker)=totOpen/(timeChange-1);
    tracker=tracker+1;
end
tracker=1;
for i=11:10:trainLen-timeChange
    totClose=sum(trainingVal(i+1:i+timeChange-1));
    %drift=trainingVal(i+2)-trainingVal(i+1);
    changeClosed(tracker)=totClose/(timeChange-1);
    tracker=tracker+1;
end

avOpen=mean(changeOpen);
avClose=mean(changeClosed);

%drift=trainingVal(end)-trainingVal(end-1);

end

