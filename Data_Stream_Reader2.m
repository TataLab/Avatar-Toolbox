%Sets up serial communication with Avatar recorder and creates some
%globals that will be needed to mediate data recording

 
SetEEGConfig_series2000;  %call the setup script to configure settings


%*********set up some global structures to hold data****************

%eegSession will hold some key settings as well as some temp variables, mostly you won't need to look under this hood
global eegSession;  eegSession=struct;  
eegSession.D = []; %will act as a frame buffer to hold partial frames across callbacks
eegSession.D = cast(eegSession.D,'uint8'); %force the array to be 1-byte ints
eegSession.dataFrameIndex = 1; %a book keeping index to keep track of where to write the next data frame into the eegD array
eegSession.btDataStreamReady = 0;  % a flag to indicate all is well
eegSession.frameStartsList = [];


%here's the main data structure:

%the eegD struct contains the following fields:
% .data                     -  the first filed of the eegD cell structure will contain an 8 row array of doubles to hold eeg data 
%.time                      - the second element of the eegD cell structure will contain a vector of
%                                   uint64s to hold the time stamps,  we'll
%                                   collect one time stamp for each frame
%                                   using tic() and then interpolate the
%                                   others
 %.originalTimes     - the third element holds only the time stamps corresponding to the "tic'd" samples; that is, without interpolation.  You might want this if you want to try other interpolation approaches
 %.corrupt                 -holds an account of any frames that fail a CRC
 %check

 
 
global eegD; eegD=struct; 
eegD.data = double(zeros(EEG_Config.numChans,EEG_Config.sessionDuration*EEG_Config.SRate)); 
eegD.time = uint64(zeros(1,EEG_Config.sessionDuration*EEG_Config.SRate));
eegD.originalTimes = uint64([]);
eegD.corrupt = [];  

%%%%%%%%%%% Set up the serial port object%%%%%%%%%%
%this is specific to the Mac OS but probably pretty similar on other
%platforms.  If you modify this to work on windows or linux or etc. please
%make a new version and share it with the community

display('will try to get some data');

serialDeviceName = EEG_Config.device;
%create the serial port object
eegSession.EEGDevicePort = serial(serialDeviceName);

clear serialDeviceName; %we don't need it cluttering up the workspace

%set appropriately for Avatar device
eegSession.EEGDevicePort.BaudRate=115200;
eegSession.EEGDevicePort.InputBufferSize = EEG_Config.frameSize; 
eegSession.EEGDevicePort.OutputBufferSize=10; %number of bytes for a time-set write frame
eegSession.EEGDevicePort.ByteOrder = 'bigEndian';

eegSession.EEGDevicePort.BytesAvailableFcnMode='byte';
eegSession.EEGDevicePort.BytesAvailableFcnCount=EEG_Config.frameSize; % in bytes .BytesAvailableFcn will be called when this number is reached
%register the callback to be called when the data buffer is full, pass it
%the size of the epoch to get from the serial port buffer


eegSession.elapsedTimeBetweenFrames = [];  %use tic and toc to actually measure the elapsed times between data frames.  It should be very very close to 1/sample rate * number of samples per frame
eegSession.bestGuessAtDeltaT=uint64(0);  %on each frame we'll tic and average the most recent tics and try to make a best guess conversion factor to convert Avatar time to system time


%2000 series and 3000 series Avatar recorders have different data formats
%(the time structures arive at different points in the data stream)
%so we need to register different callbacks for the two different devices
%this is controled by a line in EEG_Config

if(strcmp(EEG_Config.version,'series2000'))
        eegSession.EEGDevicePort.BytesAvailableFcn = @getNewData_series2000; 
elseif (strcmp(EEG_Config.version,'series3000'))
        eegSession.EEGDevicePort.BytesAvailableFcn = @getNewData_series3000;
end

eegSession.EEGDevicePort.UserData.isNew=0;

close; %close the serial port if it is open
%open the serial port data stream
display('Serial port is ...');
if( strcmp(eegSession.EEGDevicePort.Status,'open') == 0) %open the port if necessary
    fopen(eegSession.EEGDevicePort);
end

display(['...' eegSession.EEGDevicePort.Status]);

pause(1);  %give the serial port hardware a moment to compose itself before recording data

eegSession.btDataStreamReady = 1;

%*******Now the data stream should be reading nicely into the eegD
%array***********

