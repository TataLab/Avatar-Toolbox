function [ trainingVal ] = training3(trainLen, setDelay, port, b, Fs)
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

track=1;
%Enter the training loop that will switch states and add the alpha activity
%over each recorded second to the vector trainingVal.
for k=1:trainLen
    ok=port.read(b);
 
    x=cat(2,x,str2num(char(b.toString())));
        
    freq = 0:Fs/500:Fs/2;
    if k>1
        j=5;
    else
        j=0;
    end
    
    for y=1:j
    xdft = fft(x((1+((y-1)*100)):(500+((y-1)*100))));
    xdft=abs(xdft);
    % I only need to search 1/2 of xdft for the max because x is real-valued
    xdft=xdft(1:500/2+1);
        
    desired1 = find(freq <= 14,1,'last');
    desired2 = find(freq >=10,1,'first');
    trainingVal(track)=mean(xdft(desired2:desired1));
    track=track+1;
    end
    if mod(k,2) == 0
        sound(y,Fs2);
    end
    x(1:500)=[];
end

end

