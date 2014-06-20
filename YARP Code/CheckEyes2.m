LoadYarp;
import yarp.Port
import yarp.DataProcessor
import yarp.Bottle

%Load the appropriate device settings. 
SetEEGConfig_series4000;

%Set the variable Fs to the sampling rate in the device's config file. 
Fs = EEG_Config.SRate;
%Set the length of time you wish to train the user in seconds. 
trainLen=30;
%Set the amount of time in seconds that will be ignored at the start of the
%training session to allow the device to compose itself. Note this must be
%less than trainLen. 
setDelay=10;

%Sets the amount of seconds/samples that go into calculating the linear
%shift in the EEG data. 
dataLen=trainLen-setDelay;

%This variable holds the current state of the user's eyes. If it is 0 then
%the users eyes are open, if 1 then the eyes are closed. 
theEyes=0;

%Create a bottle to act as a buffer reading data from the file that is
%actually streaming eeg data.
b=Bottle;
%This variable holds 0 if we wish to continue measuring if the eyes are
%closed or open but will hold 1 if we wish to exit that loop. 
done=0;
%Set this variable to the number of channels enabled in the config file. 
Channels=EEG_Config.numChans;
%Create a yarp port object to get data from the eeg streaming file. 
port=Port;
%first close the port just in case
port.close;

disp('Going to open port /matlab/read');
port.open('/matlab/read');

disp('Please connect to a bottle sink (e.g. yarp write)');
disp('The program closes when ''quit'' is received');

theData=[];
disp(['Keep eyes open to start the test. Every time you hear a beep alternate which state your eyes are in (if open then close them, if closed then open them)']);

%Try a different training method tomorrow. try alternating eyes open and
%closed by generating beeps for the user to know when to close or open
%their eyes. Take two samples before generating a beep. Take the first
%sample as the total change of opening or closing, and then take the change
%from first to second as the drift and subtract that from the total change.
%This isn't perfect, but it will hopefully generate close enough results
%that we will be able to track the change of eyes open or closed in real
%time. 

Fs = 1000;      %# Samples per second
toneFreq = 500;  %# Tone frequency, in Hertz
nSeconds = 0.5;   %# Duration of the sound
y = sin(linspace(0, nSeconds*toneFreq*2*pi, round(nSeconds*Fs)));

%one issue to adress is what if it is an increase in the negative direction
%so we will have to do something using absolute values but first checking
%whether the current voltage is above or below zero. If below zero apply
%the absolute value to the change. Then we will have to apply this as well
%to the non-training section to. 
for k=1:trainLen
    ok=port.read(b);
    theData=str2num(char(b.toString()));
    x=theData;
    freq = 0:Fs/length(x):Fs/2;
    xdft = fft(x);
    xdft=abs(xdft);
    % I only need to search 1/2 of xdft for the max because x is real-valued
    xdft=xdft(1:length(x)/2+1);
        
    desired1 = find(freq <= 14,1,'last');
    desired2 = find(freq >=10,1,'first');
    trainingVal(k)=mean(xdft(desired2:desired1));
    if mod(k,2) == 0
        sound(y,Fs);
    end
end

changeClosed=[];
changeOpen=[];
tracker=1;

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

%Enter the training session the subject must keep their eyes open during
%this time. A sample is taken every second and then with these samples we
%can calculate that linear shift and the final baseline value for checking 
%if their eyes are open or closed. 
% for k=1:trainLen
% 	ok=port.read(b);
%     
%         %check for difference in 12Hz activity
%         %this will be used to calculate the baseline.
%    
%        if(ok)
% 			if(k>setDelay)
%                 theData=str2num(char(b.toString()));
%                 x=theData;
%                 freq = 0:Fs/length(x):Fs/2;
%                 xdft = fft(x);
%                 xdft=abs(xdft);
%         % I only need to search 1/2 of xdft for the max because x is real-valued
%                 xdft=xdft(1:length(x)/2+1);
%         
%                 desired1 = find(freq <= 14,1,'last');
%                 desired2 = find(freq >=10,1,'first');
%                 trainingVal(k-setDelay)=mean(xdft(desired2:desired1))
%             end
%        end
%   
% end

% linearShift=0;
% for i=1:dataLen-1
% 	linearShift=linearShift+(trainingVal(i+1)-trainingVal(i));
% end

%linearShift now holds the amount that the eeg signal has been shifting
%either upwards or downwards during the training session. 

%linearShift=linearShift/(dataLen-1);

%Or call linearShift=0 if there is no shifting in the EEG data. 
%linearShift=0;

%Calculate the current baseline value for the eeg signal. 
norm=trainingVal(end);

disp('Training complete feel free to open and close your eyes');

%Enter into the loop that will continually check which state the users eyes
%are in. It takes samples every second and interpolates the data along the
%12hz frequency, and then decides if it has risen enough from baseline. If
%it has then it sends the signal eyes closed if not it sends the signal
%eyes open. 
while done==0
    
   
    ok=port.read(b);
    if(~ok)
        break;
    end
    theData=str2num(char(b.toString()));
        
        %check for difference in 12Hz activity
        %write either eyes open or eyes closed
        
        x=theData;
        freq = 0:Fs/length(x):Fs/2;
        xdft = fft(x);
        xdft=abs(xdft);
        % I only need to search 1/2 of xdft for the max because x is real-valued
        xdft=xdft(1:length(x)/2+1);
        
        desired1 = find(freq <= 14,1,'last');
        desired2 = find(freq >=10,1,'first');
        result=mean(xdft(desired2:desired1))
        
        %Calculate the percentage increase in the alpha frequency from
        %baseline.
        perInc=((result-norm)-drift);
        
        %Compare the percentage increase from baseline with a constant
        %number representing the minimum amount of voltage increase that is
        %required to occur. If it is greater than this number that
        %means the jump in voltage was due to the eyes closing and
        %therefore display eyes closed. 
        if(theEyes==0)
            if(perInc>avClose)
                disp('eyes closed');
                theEyes=1;
            else
                disp('eyes open');
                drift=result-norm;
            end
            if (strcmp(b.toString, 'quit'))
                done=1;
            end
        else
            if(perInc<avOpen)
                disp('eyes open');
                theEyes=0;
            else
                disp('eyes closed');
                drift=result-norm;
            end
            if (strcmp(b.toString, 'quit'))
                done=1;
            end
        end
     
	   norm=result;
    

end

port.close;

