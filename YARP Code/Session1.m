function done= Session1( port, b, norm, avOpen, avClose, drift, Fs )
%This function matches the function training1 in that it will use the data
%from that training session and then allow for real time detection of which
%state the user's eyes are currently in. 

%Variable for storing raw eeg data.
x=[];
%set to 0 if we should stay in the while loop set to 1 if we want to leave
%the while loop.
done=0;
%Stores which state the user's eyes are currently in. 0==open, 1==closed. 
theEyes=0;

%Enter our main loop to continually check and output which state the user's
%eyes are in. 
while done==0
    
   
    ok=port.read(b);
   
        if (strcmp(b.toString, 'quit'))
                break;
        end
    x=str2num(char(b.toString()));
        
        %check for difference in 12Hz activity
        %write either eyes open or eyes closed
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


end

