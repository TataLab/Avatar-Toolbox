%configure the Avatar EEG Device


global EEG_Config; EEG_Config = struct;

EEG_Config.device = '/dev/tty.AvatarEEG04035-SPPDev'; %4000 series avatar port name. 
EEG_Config. version = 'series4000'; %flag which Avatar recorder we're using
EEG_Config.SRate = 500; %sample rate
EEG_Config.protocol = 4; %protocol version
EEG_Config.numChans = 2; %minimum is 2 (apparently...setting NUMBER_OF_CHANNELS to 1 in the config.txt file on your device may cause it to incorrectly report the frame size...an undocumented limitation on the avatar hardware?)
EEG_Config.headerSize=20; %The size of the header of each frame. 20 for 4000/3000 series, 12 for 2000 series. 
EEG_Config.numCRCBytesPerFrame = 2; %The number of CRC Bytes at the end of the frame. 2 for 4000/3000 series, 0 for 2000 series. 
EEG_Config.samplesPerFrame = 16; %The number of samples in each data frame. 
EEG_Config.bytesPerSample = 3; %24-bit values from the ADC

EEG_Config.dataBytesPerFrame=EEG_Config.numChans*EEG_Config.samplesPerFrame*EEG_Config.bytesPerSample; %bytes of data per frame
EEG_Config.frameSize = EEG_Config.dataBytesPerFrame+EEG_Config.headerSize+EEG_Config.numCRCBytesPerFrame; %bytes per data frame including header

display(['dataBytesPerFrame is set to ' num2str(EEG_Config.dataBytesPerFrame)]);
display(['frame size is set to ' num2str(EEG_Config.frameSize)]);

EEG_Config.fractionalSeconds = 4096;  %number of ticks of the fractional seconds counter between seconds
EEG_Config.voltageRange = double(0.75 );  %a function of the gain setting in your config.txt file on the microSD card...look it up in the docs...for gain of 12 (typical for EEG) use voltage range of 0.75...for gain of 1 (good for inputing signals for testing) use voltage range of 9.0


%these are parameters specific to your data collection session
EEG_Config.sessionDuration = 60*8; %how long will you collect data in seconds?  Better to overstimate!

