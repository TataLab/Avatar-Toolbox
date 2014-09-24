function [erpOut,timeAxis, goodEvents] = MakeAnERP(eegDataArray, timeVector, theseEvents,numChans, epochLength, useRejection,artifactChan)

%make an ERP with the given event times and eeg data (chans x samples)
%use artifact rejection if useRejection is set

%modified (cludged) Nov. 20, 2013 by M.S.T so that number of chans and epoch length can be passed as
%an argument, this is a programming convenience (i.e. I'm lazy) if you're
%using another script that also defines epoch lengths and/or number of
%channels...someday it could all be woven together into a global parameter
%struct

%modified Nov 21, 2013 my M.S.T to optionally return a vector of the events
%that passed artifact rejection

kEpochSize = epochLength; %in samples
kBaselineStart =-200; %samples before stimulus onset to use as baseline
kBaselineSize = 200; %samples of baseline duration
kNumChans = numChans;
kSampleRate = 500;
kSamplePeriod = 1000/kSampleRate; %in ms
timeAxis = linspace(kBaselineStart*kSamplePeriod,(kEpochSize+kBaselineStart)*kSamplePeriod, kEpochSize);

kArtifactThreshold = 0.000150; %in volts; reject if any sample exceeds +/- this value

kNumEvents = size(theseEvents,2);

tempGoodEvents = []; %store a vector of the events that were accepted
numRejectedEvents=0; %keep track of how many events were rejected

eegDataArray = squeeze(eegDataArray); %in case a singleton dimension got passed it, for example if sending in a slice of a multisubject array



for i=1:kNumEvents


    %find the epoch start
    eventIndex = nearest(timeVector(1,:),theseEvents(i));  %there should only be one match!
    
    %baseline shift the epoch
    try
    epochStart = eventIndex+kBaselineStart;
    thisEpoch = eegDataArray(:,epochStart:epochStart+kEpochSize-1);
    
    baseline = mean(thisEpoch(:,1:kBaselineSize),2);

    catch
        display('a problem!');
        display(['event index: ' num2str(eventIndex) ' epochStart: ' num2str(epochStart) '  kEochSize:' num2str(kEpochSize) ]);
    end
    
    %baseline correction
    for b=1:kNumChans
        thisEpoch(b,:) = thisEpoch(b,:) - baseline(b,1);
    end
    
    
    reject = 0;
    
    if useRejection==1
        %check for artifact on the chanel we're going to plot
     
        
        if max(abs(thisEpoch(artifactChan,:))>kArtifactThreshold)
            reject=1;
            numRejectedEvents=numRejectedEvents+1;
            display(['Rejected event ' num2str(i)]);
        end
        
    end
      
    %add this epoch to the array of epochs we'll use to make the ERP
   if reject==0
   theEpochs(i,:,:) = thisEpoch;
   tempGoodEvents = [tempGoodEvents i];
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
goodEvents = tempGoodEvents;


end