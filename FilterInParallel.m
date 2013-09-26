function [ filtered_data ] = FilterInParallel( data, low, high )
%use eeglab's eegfilt() in a parfor

tempD=zeros(size(data));

kNumChans = size(data,1);
parfor c=1:kNumChans
    
    display(['Filtering channel ' int2str(c)]);
    tempD(c,:) = eegfilt(data(c,:),500,low,high);
    
    
end


filtered_data=tempD;

end

