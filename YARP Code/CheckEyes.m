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
disp(['Keep eyes open for the ', num2str(trainLen), ' second training session. A message will appear when the training is complete');

%Enter the training session the subject must keep their eyes open during
%this time. A sample is taken every second and then with these samples we
%can calculate that linear shift and the final baseline value for checking 
%if their eyes are open or closed. 
for k=1:trainLen
	ok=port.read(b);
    
        %check for difference in 12Hz activity
        %this will be used to calculate the baseline.
   
       if(ok)
			if(k>setDelay)
                theData=str2num(char(b.toString()));
                x=theData;
                freq = 0:Fs/length(x):Fs/2;
                xdft = fft(x);
                xdft=abs(xdft);
        % I only need to search 1/2 of xdft for the max because x is real-valued
                xdft=xdft(1:length(x)/2+1);
        
                desired1 = find(freq <= 14,1,'last');
                desired2 = find(freq >=10,1,'first');
                trainingVal(k-setDelay)=mean(xdft(desired2:desired1))
            end
       end
  
end

linearShift=0;
for i=1:length(trainingVal)-1
	linearShift=linearShift+(trainingVal(i+1)-trainingVal(i));
end

%linearShift now holds the amount that the eeg signal has been shifting
%either upwards or downwards during the training session. 
linearShift=linearShift/(length(trainingVal)-1);

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
        perInc=((result-norm)/norm)*100;
        
        %Compare the percentage increase from baseline with a constant
        %number representing the minimum amount of voltage increase that is
        %required to occur. If it is greater than this number that
        %means the jump in voltage was due to the eyes closing and
        %therefore display eyes closed. 
        if(perInc>10)
            disp('eyes closed');
        else
            disp('eyes open');
        end
        if (strcmp(b.toString, 'quit'))
            done=1;
        end
     
	   norm=norm+linearShift
    

end

port.close;

