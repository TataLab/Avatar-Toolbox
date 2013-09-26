test_file = fopen("one_frame_test.bin", "r");
tempD = fread(test_file, 166, 'uint8'); % one frame happens to be 166 bytes in this case
tD = tempD(21:164); % take the data
tD = reshape(tD,3,[]);
tD_int32(1)=typecast([uint8(0) tD(3,1) tD(2,1) tD(1,1)],'int32');
tD_int32(2)=typecast([uint8(0) tD(3,2) tD(2,2) tD(1,2)],'int32');
tD_int32(3)=typecast([uint8(0) tD(3,3) tD(2,3) tD(1,3)],'int32');
tD_double = double(tD_int32) * 0.750 / (2^32) % convert to volts

