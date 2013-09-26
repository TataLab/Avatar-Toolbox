function getNewData_series3000(EEGDevicePort,~,~)
%the strategy will be to use the vector D as a sort of FIFO buffer by
%continuously pulling complete frames off the front while simultaneously
%appending to the back


%some ideas for error handling (not yet implemented):
%   - count bytes between headers to make sure that the entire frame has
%   arrived (or use the CRC)?
%
%   -if the entire frame isn't available we can't know which sample(s) got
%   dropped, so abandon the entire frame
%
%  - since eegD is initialized with NaNs we can use the frame count in each
%  header as the index (zero it first) to populate eegD where the frames
%  need to go, leaving NaNs were a frame was dropped
%
%  - a post-processing step could interpolate the missing frames



global eegD;
global EEG_Config;
global eegSession;

tD_int32 = cast(zeros(1,EEG_Config.numChans*EEG_Config.samplesPerFrame),'int32'); %initialize a matrix to hold 32-bit values


%read one frame worth of data...note this doesn't mean you read one frame
%from start to finish...the frame might start anywhere within these 396
%bytes

tempD = fread(eegSession.EEGDevicePort,EEG_Config.frameSize,'uint8'); %get .frameSize bytes = one data frame worth of data (note it might start anywhere in the frame!)



if eegSession.btDataStreamReady==1 %don't start recording until we're ready (e.g. the serial port has had a moment)
    
    
    eegSession.D=[eegSession.D,cast(tempD','uint8')]; %append the current data to the end of the buffer
    
    if (size(eegSession.D,2)>=EEG_Config.frameSize*2) %if we've accumulated 2 full frames (or more) then take the first frame off the front of the vector
        
        %find what we know to be the first 4 bytes of the header
        frameStarts = strfind(eegSession.D,[170 67 1 150]);  %the frame start is the first element of this vector  (which should never be more than size 2 anyway)
        
        %*******EEG Data************
        %this proces takes 3x8bit words, merges them into a 24bit samples stored as 32-bit signed ints,
        %then, sorts them into chans x samples
        
        tD = eegSession.D((frameStarts(1)+EEG_Config.headerSize):(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame-1));
        
        %HERE's where some basic data integrity checking should
        %probably happen...after extracting a single frame from
        %EEGSession.D but before reshaping/casting it
        %
        %The code to check CRC could be written into a seperate .m file
        %and called from here, but it might be better to write it in
        %here to prevent the toolbox from getting unwieldy
        
        tD = reshape(tD,3,[]); %reshape so that each 24-bit sample is a column of three 8-bit uint8s
        
        %now collapse three 8-bit words into one 32-bit word (by including a fourth byte of zeros)
        
        for i=1:size(tD,2)
            tD_int32(i)=typecast([uint8(0) tD(3,i) tD(2,i) tD(1,i)],'int32');
        end
        
        tD_double = double(tD_int32) .* EEG_Config.voltageRange / (2^32);% - EEG_Config.voltageRange/2;  %times the range, divided by 2^24 converts from ADC units to volts - half the range centers it
        
        eegD.data(1:EEG_Config.numChans,eegSession.dataFrameIndex:eegSession.dataFrameIndex+EEG_Config.samplesPerFrame-1) = reshape(tD_double,8,[]);
        
        %********EEG Data *************
        
        
        %*******Time data*******
        %pull out the unix time and fractional seconds
        seconds=typecast([eegSession.D(frameStarts(1)+17) eegSession.D(frameStarts(1)+16) eegSession.D(frameStarts(1)+15) eegSession.D(frameStarts(1)+14)],'uint32');
        fracSeconds = typecast([eegSession.D( frameStarts(1)+19) eegSession.D(frameStarts(1)+18)],'uint16');
        
        seconds = cast(seconds,'uint64');
        fracSeconds = cast(fracSeconds,'uint64');
        
        frameTime = uint64((1000*seconds) + (1000*fracSeconds/EEG_Config.fractionalSeconds));
        eegD.time(1,eegSession.dataFrameIndex)=frameTime;
        
        %fill in times for the samples in between headers
        for j=1:EEG_Config.samplesPerFrame-1
            eegD.time(1,eegSession.dataFrameIndex+j) = frameTime + j*(1000/EEG_Config.SRate); %assume the samples are indeed linear in time
        end
        
        eegSession.theCurrentFrameTime = frameTime; %important!  update the clock whenever possible
        
        %this is for initial testing, left it in just in case we need to
        %recheck...Matt
        %eegSession.elapsedTimeBetweenFrames = [eegSession.elapsedTimeBetweenFrames toc(eegSession.withinFrameElapsedTime) * 1000]; %toc the previous frame time before resetting it, report it in millis for convenience
        
        eegSession.withinFrameElapsedTime = tic;  %tic the time now, toc it later and add the difference in millis to the most recent frame time:  this is the best guess of the immediate time on the EEG Device's clock
        
        
        %******END Time data********
        
        
        
        %*****Clean up the data buffer and update the frame index for
        %the next frame
        eegSession.dataFrameIndex = eegSession.dataFrameIndex+EEG_Config.samplesPerFrame;
        eegSession.D(1:EEG_Config.frameSize) = [];  %remove the entire first frame from the data buffer
        
    end
    
end

end




