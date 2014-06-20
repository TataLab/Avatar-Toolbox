function [ eegTime ] = GetCurrentEEGTime( )
%the callback function responsible for parsing and storing EEG data and header info (including time)
%updates the global variable theCurrentFrameTime with the most recent unix
%timestamp in the most recent header.  Since headers only come along every
%data frame (not every sample!) this clock is always behind - by as much as
%~32 milliseconds for a typical 16 sample data frame.   To account for the
%time elapsed since the last data frame, the callback also tics a global
%variable called.
%
%this function checks  theCurrrentFrameTime and tocs the global variable
%withinFrameElapsedTime to try to estimate the real current time *on the Avatar
%clock*

 


eegTime = tic();


end

