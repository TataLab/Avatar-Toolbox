function [PSD, avgPSD] = ComputePSD( epochs, Fs )
%Takes an array of epochs and computes the PSD data object


kNumEpochs = size(epochs,1);
kLengthEpochs = size(epochs,2);

tempXs=zeros(kNumEpochs,floor(kLengthEpochs/2+1));


for i=1:kNumEpochs

    X=fft(epochs(i,:));
    tempXs(i,:)=X(1:length(X)/2+1); %one-sided DFT
    P=(abs(tempXs(i,:))/kLengthEpochs).^2; %compute the mean-square power
    P(2:end-1)=2*P(2:end-1); %Factor of two for one-sided estimate at all frequencies except zero and nyquist
%     P(1)=[]; %remove the DC component
%     P(end)=[]; %remove the nyquist limit component
    tempPSD(i,:) = dspdata.psd(P,'Fs',Fs,'spectrumtype','onesided');
    

end

avgX=mean(tempXs,1); %average the FFT across all epochs
avgP=(abs(avgX)/kLengthEpochs).^2;
avgP(2:end-1)=2*avgP(2:end-1);

avgPSD = dspdata.psd(avgP,'Fs',Fs,'spectrumtype','onesided'); %output the mean-square power of the averaged FFT
PSD = tempPSD; %output the array of mean-square power on each trial
end

