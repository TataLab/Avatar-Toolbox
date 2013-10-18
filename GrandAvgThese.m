function [gAvg] = GrandAvgThese( allERPsArray )
%pass an array chans x samples x subs and it collapses across subjects

gAvg = mean(allERPsArray,3);


end

