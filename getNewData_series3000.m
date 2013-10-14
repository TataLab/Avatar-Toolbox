function getNewData_series3000(EEGDevicePort,~,~)
%the strategy will be to use the vector D as a sort of FIFO buffer by
%continuously pulling complete frames off the front while simultaneously
%appending to the back
%
%
%Written by Matt Tata and Josh Pepneck
%
%
%known problems:
%           -time stamps are not quite right because the first sample in
%           the buffer fram is stamped with tic() when the callback
%           executes.  It should be the last sample!
%
%           -waits for two full frames to arrive before starting to parse,
%           this incurrs unfortuntate lag,  what can we do about it?  It
%           seems we need to do this to ensure that we have at least one
%           full frame to work on in the D buffer


%grab the system time right away, we'll use it below
currentFrameSystemTime = tic();


global eegD;
global EEG_Config;
global eegSession;

tD_int32 = cast(zeros(1,EEG_Config.numChans*EEG_Config.samplesPerFrame),'int32'); %initialize a matrix to hold 32-bit values

%read one frame worth of data...note this doesn't necessarily mean you read one frame
%from start to finish...the frame might start anywhere within these 
%bytes...

tempD = fread(eegSession.EEGDevicePort,EEG_Config.frameSize,'uint8'); %get .frameSize bytes = one data frame worth of data (note it might start anywhere in the frame!)


if eegSession.btDataStreamReady==1 %don't start recording until we're ready (e.g. the serial port has had a moment)
     
    eegSession.D=[eegSession.D,cast(tempD','uint8')]; %append the current data to the end of the buffer   
    
    if (size(eegSession.D,2)>=EEG_Config.frameSize*2) %if we've accumulated 2 full frames (or more) then take the first frame off the front
        
        %find what we know to be the first 4 bytes of the header
        %we have to compute the appropriate frame size for bytes 3 and 4
        frameSizeBytes=typecast(uint16(EEG_Config.frameSize),'uint8'); %take the 16-bit number and make it two 8-bit numbers
              
        frameStarts = strfind(eegSession.D,[170 67 frameSizeBytes(2) frameSizeBytes(1)]);  %the frame start is the first element of this vector  (which should never be more than size 2 anyway)
        
        eegSession.frameStartsList=[eegSession.frameStartsList frameStarts];
        %*******EEG Data************
        %this proces takes 3x8bit words, merges them into a 24bit samples stored as 32-bit signed ints,
        %then, sorts them into chans x samples
       
        %getting the entire frame not including the CRC bits so that we can
        %calculate a new CRC to check against the existing one. 
        
        %we could also do the check by taking the entire frame including
        %the crc bits and seeing if it's crc check returns zero if not
        %something got switched. 
        tHD= eegSession.D((frameStarts(1)):(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame-1));
        
        %turning the current CRC into a 2 byte decimal number
        tempCRC=typecast([eegSession.D(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame+1), eegSession.D(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame)], 'uint16');
        
        %creating the CRC from the tHD
        checkCRC=CRC(tHD);
                
        %checking our two different CRC's to see if they match or not. 
        if(tempCRC~=checkCRC)
            disp('CRC not matching bit(s) corrupted!');
            for k=0:EEG_Config.samplesPerFrame-1
                eegD.corrupt(1,eegSession.dataFrameIndex+k) = 1;
            end
            
            %do something here to fix the problem: thoughts right now
            %initialize the whole frame to zeros if the size is off so data
            %is missing. Then just ignore this frames information in the data processing. If it is just a bit that got switched somewhere
            %and no data is actually missing then, interpolate an average
            %with previous and future data?
       
        end
        
        %End of the CRC check. 
        

        tD = eegSession.D((frameStarts(1)+EEG_Config.headerSize):(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame-1));
        
        tD = reshape(tD,3,[]); %reshape so that each 24-bit sample is a column of three 8-bit uint8s
        
        %now collapse three 8-bit words into one 32-bit word (by including a fourth byte of zeros)
        for i=1:size(tD,2)
            tD_int32(i)=typecast([uint8(0) tD(3,i) tD(2,i) tD(1,i)],'int32');
        end
        
        tD_double = double(tD_int32) .* EEG_Config.voltageRange / (2^32);  %times the range, divided by 2^24 converts from ADC units to volts since the number is actually 32 bits a division by 2^32 is required instead of 2^24
       
        eegD.data(1:EEG_Config.numChans,eegSession.dataFrameIndex:eegSession.dataFrameIndex+EEG_Config.samplesPerFrame-1) = reshape(tD_double,EEG_Config.numChans,[]);
       
        %********End EEG Data Collection*************
        
        
        %*******Handle Time data*******
        %eegD.time(1,eegSession.dataFrameIndex)=currentFrameSystemTime;  %set the first sample of this time stamp to be the current system time 
        %******Time data********
        
        %%!!change this!  This is stamping the first sample in this frame
        %%with a time much closer to that of the last sample in the frame
        
        
        
        %*******Handle Time data*******
        eegD.time(1,eegSession.dataFrameIndex)=currentFrameSystemTime - uint64(EEG_Config.samplesPerFrame * 1/EEG_Config.SRate * 1000000000);  %set the first sample of this time stamp to be an estimate of the system time when it was recorded.  Since we're chunking > 1 data frame we know it was at least sample period x num samples per frame ago 
        %******Time data********
        
        
        
        
        %*****Clean up the data buffer and update the frame index for
        %the next frame
        eegSession.dataFrameIndex = eegSession.dataFrameIndex+EEG_Config.samplesPerFrame;
        eegSession.D(1:EEG_Config.frameSize) = [];  %remove the entire first frame worth of data from the data buffer
        
        
        %check to see if we've run out of session
        if((eegSession.dataFrameIndex/EEG_Config.SRate)>=EEG_Config.sessionDuration)
            eegSession.btDataStreamReady=0;
            fclose(eegSession.EEGDevicePort);
            display('Problem.  You ran out of session duration. Abort.');
        end
        
    end %if size is bigger than two data frames
    
end %if bluetooth stream is ready

end %the function is done




