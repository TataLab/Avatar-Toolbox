
global eegSession;

display('Shutting down the bluetooth data stream...');
%close the data stream
fclose(eegSession.EEGDevicePort);
display('done');

%clean up the data array

%fill in the timestamps that we didn't record (should be 2nd through 16th
%of each data frame)

display('interpolating timepoints between data frames...');

eegD.originalTimes = eegD.time;

time_doubles = typecast(eegD.time,'double'); %interp1 only works on doubles, grr

vectorOfTimeStamps = find(time_doubles ~=0);  %find the indices where we do have time stamps (should start at 1 and go every 16th)


for i = 2 : length(vectorOfTimeStamps)

   x = vectorOfTimeStamps(i-1:i); %two elements at either end of the region we have to fill in
   
   yi = interp1(x,time_doubles(x),x(1):x(2));  %linear interpolation between either end of the region
   
   yi_uint64 = typecast(yi,'uint64'); %cast back to uint64, note you can't use double() and uint64() to do this because it loses precision (for some reason)
   
   eegD.time(x(1):x(2))=yi_uint64; %replace with the linear interpolation and typecast back to uint64
   
   
end

display('done');

display('You have new EEG data.  Have a nice day.');


