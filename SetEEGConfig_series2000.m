%configure the Avatar EEG Device


global EEG_Config; EEG_Config = struct;


EEG_Config.device = '/dev/tty.LairdBTM03227C-SPPDev';
EEG_Config. version = 'series2000';
EEG_Config.SRate = 500; %sample rate
EEG_Config.protocol = 3; %protocol version
EEG_Config.frameSize = 396;%396 for all 8 channels
EEG_Config.dataBytesPerFrame=384; %bytes of data per frame 384
EEG_Config.numCRCBytesPerFrame = 0;
EEG_Config.headerSize=12;
EEG_Config.samplesPerFrame = 16;
EEG_Config.bytesPerSample = 3; %24-bit values from the ADC
EEG_Config.numChans = 8;
EEG_Config.fractionalSeconds=32768;
EEG_Config.voltageRange = 0.750;  %a function of the gain setting in your config.txt file on the microSD card...look it up in the docs


%these are parameters specific to your data collection session
EEG_Config.sessionDuration = 60*5; %how long will you collect data in seconds?  Better to overstimate!



%these are parameters for post-processing
EEG_Config.epochSize = 500; %in samples

EEG_Config.samplesBetweenTime=511;