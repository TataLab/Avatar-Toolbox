function [erpOut] = MakeAnERP(eegD, timeVector, theseEvents,ch, useRejection)

%make an ERP with the given event times and eeg data
%use artifact rejection if useRejection is set

kEpochSize = 800; %in samples
kBaselineStart =-200; %samples before stimulus onset to use as baseline
kBaselineSize = 200; %samples of baseline duration
kNumChans = 2;


kArtifactThreshold = 0.000100; %in volts; reject if any sample exceeds +/- this value

kNumEvents = size(theseEvents,2);


numRejectedEvents=0; %keep track of how many events were rejected

for i=1:kNumEvents


    %find the epoch start
    eventIndex = nearest(timeVector(1,:),theseEvents(i));  %there should only be one match!
    
    %baseline shift the epoch
    try
    epochStart = eventIndex+kBaselineStart;
    epoch = eegD(:,epochStart:epochStart+kEpochSize-1);
    baseline = mean(epoch(:,1:kBaselineSize),2);
    catch
        display(['event index: ' num2str(eventIndex) ' epochStart: ' num2str(epochStart) '  kEochSize:' num2str(kEpochSize) ]);
    end
    
    
    for b=1:kNumChans
        epoch(b,:) = epoch(b,:) - baseline(b);
    end
    
    
    reject = 0;
    
    if useRejection==1
        %check for artifact on the chanel we're going to plot
     
        
        
        if max(abs(epoch(ch,:))>kArtifactThreshold)
            reject=1;
            numRejectedEvents=numRejectedEvents+1;
            %display(['Rejected event ' num2str(i)]);
        end
        
    end
      
    %add this epoch to the array of epochs we'll use to make the ERP
   if reject==0
   theEpochs(i,:,:) = epoch;
   %display(['adding an event at ' num2str(theseEvents(i)) 'ms as the ' num2str(i) 'th ERP event']);
   %plot(epoch(ch,:));
   %pause(1);
   end
   
 
end

if useRejection==1
display(['Number of rejected events: ' num2str(numRejectedEvents)]);
end


%make  ERPs
ERPs = mean(theEpochs,1);
erpOut = squeeze(ERPs);



end