function done= Session2( port, b, avOpen, avClose, Fs )
%This function matches the function training2 in that it will use the data
%from that training session to detect in real time which state the user's
%eyes are currently in. 


%Variable for storing raw eeg data.
x=[];
%set to 0 if we should stay in the while loop set to 1 if we want to leave
%the while loop.
done=0;
%Stores which state the user's eyes are currently in. 0==open, 1==closed. 
theEyes=0;

%Enter our main loop for continually checking which state the user's eyes
%are currently in. 
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
        
      
        
        %Use the value stored in the variable result and check which state
        %it is closer to then output the appropriate state that the user's
        %eyes are currently in. 
            if (strcmp(b.toString, 'quit'))
                done=1;
            elseif(abs(result-avClose)<abs(result-avOpen))
                disp('eyes closed');    
            else
                disp('eyes open');
              
            end
            
end


end


