function [ result ] = eeg_read(port, b, Fs, minFreq, maxFreq)
%This function will train a user by simply making them switch between
%opening their eyes and closing their eyes every two seconds. It then
%calculates the change in eeg activity from one state to the other to be
%used later. 


%raw data from each second of eeg activity. 
x=[];


%Enter the training loop that will switch states and add the alpha activity
%over each recorded second to the vector trainingVal.
    ok=port.read(b);
    x=str2num(char(b.toString()));
    freq = 0:Fs/length(x):Fs/2;
    xdft = fft(x);
    xdft=abs(xdft);
    % I only need to search 1/2 of xdft for the max because x is real-valued
    xdft=xdft(1:length(x)/2+1);
        
    desired1 = find(freq <= maxFreq,1,'last');
    desired2 = find(freq >=minFreq,1,'first');
    result=mean(xdft(desired2:desired1));
   
end





