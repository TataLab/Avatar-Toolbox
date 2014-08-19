function done= Session( port, b, Fs, model )
%This function matches the function training1 in that it will use the data
%from that training session and then allow for real time detection of which
%state the user's eyes are currently in. 

%Variable for storing raw eeg data.
x=[];
sesLen=240;
%set to 0 if we should stay in the while loop set to 1 if we want to leave
%the while loop.
done=0;
%Stores which state the user's eyes are currently in. 0==open, 1==closed. 
theEyes=0;

%Enter our main loop to continually check and output which state the user's
%eyes are in. 
while done<sesLen
    
   
    port.read(b);
   
        if (strcmp(b.toString, 'quit'))
                break;
        end
      x=str2num(char(b.toString()));
      
      

    [temp,freqs]=periodogram(x,[],[],500,'one-sided');
    testPgrams=temp';
    
    delta=[find(freqs>=1,1,'first') find(freqs>=4,1,'first')];
    theta=[find(freqs>=5,1,'first') find(freqs>=9,1,'first')];
    alpha=[find(freqs>=10,1,'first') find(freqs>=14,1,'first')];
    beta=[find(freqs>=15,1,'first') find(freqs>=25,1,'first')];



%build the test bins same as training bins
testBins=zeros(1,4);

    testBins(1,1)=mean(testPgrams(delta(1):delta(2)));
    testBins(1,2)=mean(testPgrams(theta(1):theta(2)));
    testBins(1,3)=mean(testPgrams(alpha(1):alpha(2)));
    testBins(1,4)=mean(testPgrams(beta(1):beta(2)));


%make the classifier try to classify each epoch

    
    prediction=char(predict(model,testBins(1,:)));
    
    display(['Eyes are: ' prediction]);

      
     
 
    
done=done+1;
end


end

