%This function will take in a data array of bytes and preform the
%desired crc check to see what crc value it results in which we will then
%be able to use to check if it matches a different arrays crc. 

function crc=CRC(data)
%I choose to use a 32 bit int.I am not sure if this is the right approach
%for the variable b but b and the crc variable have to align in length in
%matlab so I choose to make them both 32 bits. 
crc = uint32(0);
    for i=1:size(data, 2)
        b = uint32(data(i));
        crc  = bitor(bitshift(crc, -8), bitshift(bitand(crc, 255), 8));
        crc =bitxor(crc, b);
        crc = bitxor(crc, bitshift((bitand(crc, 255)), -4));
        crc =bitxor(crc, bitand(bitshift(crc, 12), 65535));
        crc =bitxor(crc, (bitshift((bitand(crc, 255)), 5)));
    end
    


end
