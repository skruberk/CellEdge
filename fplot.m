function [m,b] = fplot(X,Y,cmark,axM)
% this function plots Y versus X, fits the data to a straight line and
% plots the data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% X and Y are the data to fit and plot
% cmark - is a string with color and marker information (e.g. 'or' or 'ok')
% axM - is the maximum dimension for the axis (based on plotting ref. line)


% use linear regression to find the best-fit slope of a line that runs
% through the origin: i.e. y = mx
% to deal with large slopes, we will calculate slope both ways
    
% since y = mx, the 'estimator matrix' is just X
% the observation vector is Y
% the results are contained in m
    
% solve for the slope
m = (X'*X)\X'*Y;
Yfit = m*X;

figure()
hold on
plot(X,Y,cmark)
plot(X,Yfit,'color','black','LineWidth',1)
plot(0:axM,0:axM,'color','black','LineWidth',2)
hold off

b = 0;


end