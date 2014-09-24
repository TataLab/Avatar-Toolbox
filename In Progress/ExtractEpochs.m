function [ epochs ] = ExtractEpochs( data, time ,events, chan, kEpochSize, kBaselineStart )
%find epochs associated with events and and write them into an array
%work on a single specified channel to keep the array sensible
%output will be an array that is epochs x samples

%Nov 20, 2013 modified to take data and time arrays seperately rather than
%as a single struct.  This makes the function more useful to multi-subject
%scripts


kNumEvents = length(events);

tempData = zeros(kNumEvents,kEpochSize);

for i=1:kNumEvents


    %find the epoch start
    eventIndex = nearest(time,events(i));  %there should only be one match!
    
    epochStart = eventIndex+kBaselineStart;  %index where this epoch starts
    epochEnd = epochStart + kEpochSize-1; %index where this epoch ends
    
    tempData(i,:) = data(chan,epochStart:epochEnd);
    

end


epochs = tempData;

end

