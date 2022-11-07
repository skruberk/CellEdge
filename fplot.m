function [m,b,corr,out] = fplot1(ch1k,ch2k,cmark,axM,resultsdir,avsig1,avsig2,outfile_tag)
global out
% this function plots Y versus X, fits the data to a straight line and
% plots the data
%with the new droid5b then the axM needs to be 1.5 since everything
%is scaled to 1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% X and Y are the data to fit and plot, x=ch1k y=ch2k, take the mean of
% each x and y and check to see which one is higher and divide by teh ratio
%and divide both by mean of mch beta actin
% cmark - is a string with color and marker information (e.g. 'or' or 'ok')
%
% axM - is the maximum dimension for the axis (based on plotting ref. line)


% use linear regression to find the best-fit slope of a line that runs
% through the origin: i.e. y = mx
% to deal with large slopes, we will calculate slope both ways
    
% since y = mx, the 'estimator matrix' is just X
% the observation vector is Y
% the results are contained in m
    
% solve for the slope
m = (ch1k'*ch1k)\ch1k'*ch2k;
Yfit = m*ch1k;


%this is an unwieldy way to get the linear correlation coefficient but sure
corr=zeros(2,2);
corr=corrcoef(ch2k,ch1k);
corr=unique(corr);
corr= corr(corr~=1);

%plotting stuff to get the text on the plot
str1=num2str(corr);
str1="R2:  "+ str1
str2=num2str(m)
str2="slope:  " +str2
plotmax1=(max(ch1k))/1.15
plotmax2=(max(ch2k))/1.15
plotmax3=(max(ch1k))/1.5
plotmax4=(max(ch2k))/1.5
figure()
hold on
plot(ch1k,ch2k,cmark)
plot(ch1k,Yfit,'color','black','LineWidth',1)
plot(0:axM,0:axM,'color','red','LineWidth',2)
text(plotmax1,plotmax2,str1)
text(plotmax3,plotmax4,str2)
hold off
%fplotb?

b = 0;
%this creates the outfile 
out=table(2,5);
file=[outfile_tag];
slope=[m];
r2=[corr];
ch1sum=[avsig1];
ch2sum=[avsig2];
out=table(file, slope,r2,ch1sum,ch2sum);
disp(out)
cd(resultsdir)
name=outfile_tag
writetable(out,name);
%filename = ["_" outfile_tag '.csv']
%save(filename, file, slope, r2, ch1sum, ch2sum);

%writetable(out,"results.csv")
return 
end