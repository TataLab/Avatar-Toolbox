LoadYarp;
import yarp.Port
import yarp.DataProcessor
import yarp.Bottle

SetEEGConfig_series4000;

Fs = EEG_Config.SRate;
trainLen=30;
setDelay=10;

%predefined value from training.
b=Bottle;
done=1;
Channels=EEG_Config.numChans;
port=Port;
%port.setTimeout(10);
%first close the port just in case
port.close;

disp('Going to open port /matlab/read');
port.open('/matlab/read');
%processor=DataProcessor;
%port.setReader(processor);

disp('Please connect to a bottle sink (e.g. yarp write)');
disp('The program closes when ''quit'' is received');

theData=[];
%theData2=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
loopIt=1;
disp('Keep eyes open for 30 second training session. A message will appear when the training is complete');

for k=1:trainLen
    %b=processor.getBottle();
	ok=port.read(b);
    %if(b.size()>0)
    
        
        %check for difference in 12Hz activity
        %write either eyes open or eyes closed
   
       if(ok)
			if(k>setDelay)
                theData=str2num(char(b.toString()));
                x=theData;
                freq = 0:Fs/length(x):Fs/2;
                xdft = fft(x);
                xdft=abs(xdft);
        % I only need to search 1/2 of xdft for the max because x is real-valued
                xdft=xdft(1:length(x)/2+1);
        
                desired1 = find(freq <= 14,1,'last');
                desired2 = find(freq >=10,1,'first');
                trainingVal(k-setDelay)=mean(xdft(desired2:desired1))
            end
       end
			
				
        %processor.clear();
        
    %end
    %end
  
end

linearShift=0;
for i=1:length(trainingVal)-1
	linearShift=linearShift+(trainingVal(i+1)-trainingVal(i));
end
linearShift=linearShift/length(trainingVal);
%linearShift=0;
norm=trainingVal(end);

disp('Training complete feel free to open and close your eyes');


while done<100
    
   % b=processor.getBottle();
    ok=port.read(b);
    if(~ok)
        break;
    end
    %if(b.size()>0)
    theData=str2num(char(b.toString()));

    
   % if(length(theData)>1)
    %    done=done+1;
    %end
    
   % if(theData(1:10)~=theData2(1:10))
        done=1;
        %SortedData=reshape(theData,[],Channels);
        
        %check for difference in 12Hz activity
        %write either eyes open or eyes closed
        
       
        %x=SortedData(1,:);
        x=theData;
        freq = 0:Fs/length(x):Fs/2;
        xdft = fft(x);
        xdft=abs(xdft);
        % I only need to search 1/2 of xdft for the max because x is real-valued
        xdft=xdft(1:length(x)/2+1);
        
        desired1 = find(freq <= 14,1,'last');
        desired2 = find(freq >=10,1,'first');
        result=mean(xdft(desired2:desired1))
        
        perInc=((result-norm)/norm)*100;
        
        
        if(perInc>10)
            disp('eyes closed');
        else
            disp('eyes open');
        end
        if (strcmp(b.toString, 'quit'))
            done=101;
        end
        %processor.clear();
        %theData2=theData;  
   % end
	   norm=norm+linearShift
    
  
   % end
end

port.close;