function done= Session( port, b, norm, avOpen, avClose, drift, Fs, minFreq, maxFreq )
%This function matches the function training1 in that it will use the data
%from that training session and then allow for real time detection of which
%state the user's eyes are currently in. 

%Variable for storing raw eeg data.
x=[];
sesLen=60;
%set to 0 if we should stay in the while loop set to 1 if we want to leave
%the while loop.
done=0;
%Stores which state the user's eyes are currently in. 0==open, 1==closed. 
theEyes=0;

%Enter our main loop to continually check and output which state the user's
%eyes are in. 
while done<sesLen
    
   
    ok=port.read(b);
   
        if (strcmp(b.toString, 'quit'))
                break;
        end
      x=str2num(char(b.toString()));
    
      [data,freq]=periodogram(x,[],Fs);
     
      desired1 = find(freq >= (minFreq/(Fs/2))*pi,1,'first');
      desired2 = find(freq <=(maxFreq/(Fs/2))*pi,1,'last');
      result= mean(data(desired1:desired2)); 
        
        
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
    
done=done+1;
end


end

