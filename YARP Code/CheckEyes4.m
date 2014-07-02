LoadYarp;
import yarp.Port
%import yarp.DataProcessor
import yarp.Bottle

%Load the appropriate Avatar device settings. 
SetEEGConfig_series4000;

%Set the variable Fs to the sampling rate in the device's config file. 
Fs = EEG_Config.SRate;
%Set the length of time you wish to train the user in seconds. 
trainLen=40;
%Set the amount of time in seconds that will be ignored at the start of the
%training session to allow the device to compose itself. Note this will be
%added onto the time trainLen but will simply be ignored so that the all
%the hardware has time to compose itself.
setDelay=10;

%Set which method of training you will be using. 1 is used for detecting
%change in eye state. 2 is used for detecting which state the eyes are
%currently closest to. 
Method=1;


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

disp(['Keep eyes open to start the test. There will be an initial beep, then every time you hear a']);
disp(['beep alternate which state your eyes are in (if open then close them, if closed then open them)']);

%Choose the proper method of training, and then call the appropriate
%function to perform the training. 
if Method==1
    [avOpen,avClose,drift,trainingVal]=training1(trainLen,setDelay,port,b,Fs);
elseif Method==2
    [avOpen,avClose,trainingVal]=training2(trainLen,setDelay,port,b,Fs);
end
    

norm=trainingVal(end);

disp('Training complete feel free to open and close your eyes');

%Call the appropriate function that matches which method of training we
%used. This will simply continually check each second of eeg activity in
%the alpha range, and then output which state the eyes are in (closed or
%open) based off of the user's previous training. 
if Method==1
    done=Session1(port,b,norm,avOpen,avClose,drift,Fs);
elseif Method==2
    done=Session2(port,b,avOpen,avClose,Fs);
end

port.close;

