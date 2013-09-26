function [ p , distributionOfA, distributionOfB,dif ] = ComparePSDs( PSDa,PSDb,freqRange )
%return the p-value of a Mann-Whitney U test comparing two sets of PSDs
%computes avg power within the specified frequency range and compares those
%powers

kNumPoints = size(PSDa,1); %how many epochs 

avgPowerA= zeros(kNumPoints,1);
avgPowerB=zeros(kNumPoints,1);
avgPowerDif=zeros(kNumPoints,1);

for i = 1:kNumPoints

    avgPowerA(i) = avgpower(PSDa(i),freqRange);
    avgPowerB(i)=avgpower(PSDb(i),freqRange);
    avgPowerDif(i)=avgPowerA(i)-avgPowerB(i);
end

p=ranksum(avgPowerA,avgPowerB);

distributionOfA=avgPowerA;
distributionOfB=avgPowerB;
dif=avgPowerDif;

end

