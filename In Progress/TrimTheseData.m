function [ output ] = TrimTheseData( eegD )
%find the end of the EEG session and trim off the zeros


lastSample=find(eegD.time==max(eegD.time));

tempStruct.data=eegD.data(:,1:lastSample);
tempStruct.time=eegD.time(1:lastSample);
tempStruct.originalTimes=eegD.originalTimes(1:lastSample);

output=tempStruct;


end

