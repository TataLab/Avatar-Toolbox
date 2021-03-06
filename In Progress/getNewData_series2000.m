function getNewData_series2000(EEGDevicePort,~,~)

global eegD;
global EEG_Config;
global eegSession;

%grab the system time right away, we'll use it below
currentFrameSystemTime = tic();


%{
%read one frame worth of data...note this doesn't mean you read one frame
%from start to finish...the frame might start anywhere within these
%bytes
%}

if((eegSession.dataFrameIndex/EEG_Config.SRate)<=EEG_Config.sessionDuration)
    
    tempD = fread(eegSession.EEGDevicePort,EEG_Config.frameSize,'uint8'); %get .frameSize bytes = one data frame worth of data (note it might start anywhere in the frame!)
end

if eegSession.btDataStreamReady==1 %don't start recording until we're ready (e.g. the serial port has had a moment)
    
    eegSession.D=[eegSession.D,cast(tempD','uint8')]; %append the current data to the end of the buffer
    
    if (size(eegSession.D,2)>=EEG_Config.frameSize*2) %if we've accumulated 2 full frames (or more) then take the first frame off the front of the vector
        
        %find what we know to be the first 4 bytes of the header
        frameStarts = strfind(eegSession.D,[170 1 1 140]);  %the frame start is the first element of this vector  (which should never be more than size 2 anyway)
        
        %************EEG Data**************
        
        if(eegSession.D(1,frameStarts(1)+5)==128)
            tD_int32 = cast(zeros(1,EEG_Config.numChans*(EEG_Config.samplesPerFrame-1)),'int32'); %initialize a matrix to hold 32-bit values
        else
            tD_int32 = cast(zeros(1,EEG_Config.numChans*EEG_Config.samplesPerFrame),'int32'); %initialize a matrix to hold 32-bit values
        end
        
        
        %this proces takes 3x8bit words, merges them into a 24bit samples stored as 32-bit signed ints,
        %then, sorts them into chans x samples
        
        if(eegSession.D(1,frameStarts(1)+5)==128)
            tD = eegSession.D((frameStarts(1)+EEG_Config.headerSize+24):(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame-1));
        else
            tD = eegSession.D((frameStarts(1)+EEG_Config.headerSize):(frameStarts(1)+EEG_Config.headerSize+EEG_Config.dataBytesPerFrame-1));
        end
        
        tD = reshape(tD,3,[]); %reshape so that each 24-bit sample is a column of three 8-bit uint8s
        
        %now collapse three 8-bit words into one 32-bit word (by including a fourth byte of zeros)
        
        for i=1:size(tD,2)
            tD_int32(i)=typecast([uint8(0) tD(3,i) tD(2,i) tD(1,i)],'int32');
        end
        
        tD_double = double(tD_int32) .* EEG_Config.voltageRange / (2^32);% - EEG_Config.voltageRange/2;  %times the range, divided by 2^24 converts from ADC units to volts - half the range centers it %%since the number is actually 32 bits a division by 2^32 is required instead of 2^24
        
        if(eegSession.D(1,frameStarts(1)+5)==128)
            eegD.data(1:EEG_Config.numChans,eegSession.dataFrameIndex:eegSession.dataFrameIndex+EEG_Config.samplesPerFrame-2) = reshape(tD_double,EEG_Config.numChans,[]);
        else
            eegD.data(1:EEG_Config.numChans,eegSession.dataFrameIndex:eegSession.dataFrameIndex+EEG_Config.samplesPerFrame-1) = reshape(tD_double,EEG_Config.numChans,[]);
        end
        
        %********End EEG Data acquisition *************
        
        
        %*******Handle Time data*******
         eegD.time(1,eegSession.dataFrameIndex)=currentFrameSystemTime - uint64(EEG_Config.samplesPerFrame * 1/EEG_Config.SRate * 1000000000);   %set the first sample of this time stamp to be an 
                                                                                                                                                %estimate of the system time when it was recorded.  
                                                                                                                                                %Since we're chunking > 1 data frame we know it was 
                                                                                                                                                %at least sample period x num samples per frame ago 

      
       
        %*******End Time data**********
        
                                                                                                                                                
        %*****Clean up data buffer and update********
        
        if(eegSession.D(1,frameStarts(1)+5)==128)
            eegSession.dataFrameIndex = eegSession.dataFrameIndex+EEG_Config.samplesPerFrame-1;
        else
            eegSession.dataFrameIndex = eegSession.dataFrameIndex+EEG_Config.samplesPerFrame;
        end
        eegSession.D(1:EEG_Config.frameSize) = [];  %remove the entire first frame from the data buffer  
        
        %*****End Clean up and Update***************
    
    
    
        if((eegSession.dataFrameIndex/EEG_Config.SRate)>=EEG_Config.sessionDuration)
            eegSession.btDataStreamReady=0;
            fclose(eegSession.EEGDevicePort);
            display('Problem.  You ran out of session duration. Abort.');
        end 
    
    end%two frames available
     
end %the if BTDataStreamReady


end %the function is done

