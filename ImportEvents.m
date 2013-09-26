function [events ] =ImportEvents( eventFileName, kNumEvents )


fid=fopen(eventFileName);
events =uint64( fread(fid, kNumEvents,'uint64') );
events=events'; %make them a row vector to match the dimensions of eegD.time
fclose(fid);



end

