function [kymo1,kymo2,ch1k,ch2k,ch2kymograph,pbd1] = droid5b(raw_ch1,raw_ch2,mask_dir,resultsdir,outfile_tag,path_param)
global kymo1 kymo2 ch1k ch2k avsig1 avsig2 outfile_tag resultsdir ch2kymograph pbd1


% New version of dynamic region of interest determination function that
% identifies the perimeter of a cell and follows protein dynamics in two
% channels around a user-defined segment of this perimeter. Input includes 
% the names of two directories that contain two numbered sequences of .tif 
% images of two fluorescent proteins. The perimeter and region of interest 
% are defined using from the first channel (raw_ch1). Output includes a 
% pair of kymographs computed on the same dynamically defined regions of 
% interest for both image sequences. 
% This code calls the following accessory functions:
% generic_edge2() 
% get_image_names();

% copyright 2016, RDM and KC
% adapted and expanded 2019, RDM and KC
% further revised 2022, RDM and KS

% This version analyzes two color time-lapse data sets. First it uses the 
% marker fluorescence of images in raw_ch1 to identify the cell edge and, 
% with user input, creates a dynamic region of interist around the cell
% edge. Using this region of interest the program creates a kymograph for 
% the original channel and a second, independent channel. 
%
% RDM - 5/6/2019
% CHANGES FROM DROID4: the main change is that the code first displays an
% overlaid set of cell boundaries detected by the algorithm: bdy_issue().
% This overlay image is used to select the endpoints of the dynamic region
% of interest. In addition, a background region is selected and used to
% perform a background subtraction on each image. The code also now
% computes and displays data on background and signal intensity throughout
% the time-lapse sequence to check for illumination fluctuations and
% photobleaching. Finally, the two kymographs are displayed together with
% the boundary image overlay and use-defined ROIs. 

% time step information (dummy variable at this point)
fs=5;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% INPUT PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% raw_ch1 - name of directory containing .tif image sequences of the marker
% protein (first channel) that will be used to define the cell edge
% raw_ch2 - name of directory containing second imaging channel
% mask_dir - name of (existing) directory to hold edge-masked images
% outfile_tag - string used for naming output data files. This tag helps 
%   keep track of the results of multiple runs. The tag forms a prefix to  
%   be combined with different suffixes to create consistent names for all
%   the output files. Example outfile_tag format: date_condition_trial#
% path_param - 1x4 vector holding tracking and analysis parameters
blur = path_param(1);          % gaussian blurring used to smooth images, start at 5
edge_thresh = path_param(2);   % this threshold finds the cell edge from bdy issues
ch1_max = path_param(3);       % absolute max intensity of ch1 for plotting
ch2_max = path_param(4);       % absolute max intensity of ch2 for plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% OUTPUT DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% kymo1 and kymo2 - cell structures that contain the computed paths for the
%   kymograph analysis as well as the actual kymograph data 
% avsig1 and avsig2 - average total background-subtracted image intensity
%   in each channel. Used for normalization.

% capture the name of the current directory so that we can come back
% [N.B. this is only used when we save the marked-up images]
maindir = pwd;

% get_image_names() goes to the image directory; extracts the names of all 
% the .tif images; and parses them so that they can be recoded later.
% 'name' is a cell array containing the last three characters of all the
% image names and 'forename' contains the all but the last three characters
% of the name. 
[name1,forename1] = get_image_names(raw_ch1);
[name2,forename2] = get_image_names(raw_ch2);

% n_fr is the number of frames in the data directories
n_fr = length(name1);

% create an image (bdyi) with all boundaries (defined by 'edge_thresh')
% overlaid on top of each other
bdyi = bdy_issues(raw_ch1,name1,forename1,edge_thresh,blur);
% send the composite image to the boundary_lines() function
[startl,endl,midl,bkgd] = boundary_lines(bdyi);
% use selected start, end, and midpoint lines to create binary images for
% use in finding the endpoints of the leading edge ROI
srtimage = makeline(startl(1,:),startl(2,:),bdyi);
endimage = makeline(endl(1,:),endl(2,:),bdyi);
midimage = makeline(midl(1,:),midl(2,:),bdyi);
% use makebkgd() to create a background mask for background subtraction
bkmask = makebkgd(bkgd(1,:),bkgd(2,:),bdyi);

% %%%%%%%%%
% testcomp = srtimage + endimage + midimage + bkmask;
% figure;
% imshow(testcomp);
% return
% %%%%%%%%%%%

% use data from the first channel to find the cell edge and create a set of
% moving ROIs on the leading edge
[paths,pimage] = pathfinder2(raw_ch1,resultsdir,name1,forename1,edge_thresh,blur,srtimage,endimage,midimage);
% paths - is a cell structure containing the ordered leading-edge paths 
% bg - is an n_frx2 array of background intensities for each frame
% pb - is an n_frx2 array of total intensities for each frame (photobleach)

% initialize cell arrays to hold the kymograph data
% kymo1{:,1} is the number of points in each trace (n)
% kymo1{:,2}(1:n,1:2) is the nx2 matrix of x,y coordinates of the cell edge
% kymo1{:,3}(1:n,1) is the nx1 vector of fluorescence intensities at edge
% kymo1{:,4}(1:n,1) is an nx1 vector of shifts required to align traces
kymo1 = cell(n_fr,4);
kymo2 = cell(n_fr,4);
% additional output parameters
% pb1res and pb2res are parameters that characterize photobleaching

% lwid - is the width of the region of interest at the cell edge
lwid = 20;
lrad = floor(lwid/2);
% bgd1 and bgd2 hold background noise data for all the frames
% pbd1 and pbd2 hold average background-subtracted intensity data
bgd1 = zeros(n_fr,1);
bgd2 = zeros(n_fr,1);
pbd1 = zeros(n_fr,1);
pbd2 = zeros(n_fr,1);

% run through the frames and analyze the ROIs
% the tl vector contains time lags for each frame alignment
tl=zeros(n_fr,1);
for i=1:n_fr 
    % go to the channel 1 imaging data
    cd(raw_ch1)
    % open an image of channel 1 data
    I = imread([forename1,name1{i}]);
    % blur the image 
    I2 = imgaussfilt(I,blur);
    %Median Filter
    I3 = medfilt2(I2,[1 1]); 
    I4=max(I2);
    I4=max(I4);
    I4=double(I4);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % bw variables hold sequential, processed versions of the original
    % The first step (bw) sets a threshold
    % the second step (bw2) fills in any 'holes' in the image
    % the third step (bw3) determines the size of the blobs kept
    % the fourth step (bw4) creates a (smoothed?) perimeter around every image
    % the fifth step (bw5) fills the perimeters back in
    bw = im2bw(I3,edge_thresh);
    bw2 = imfill(bw,'holes');
    % bw3 and bw4_perim are the two most useful bw images for analysis
    bw3 = bwareaopen(bw2,100); 
    bw4_perim = bwperim(bw3);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % now go to the channel 2 data directory and open an image of channel 2
    % data. Note that paths and normals, although computed from channel 1
    % data are used for both channels.
    cd(raw_ch2)
    ITWO = imread([forename2,name2{i}]);
    %KS
    I5 = imgaussfilt(I,blur);
    I5=max(I5);
    I5=max(I5);
    I5=double(I5)
    % compute normal vectors at every point of the perimeter
    % num is the length of the current path
    num = paths{i,1};
    [normals] = findnorm(bw4_perim,paths{i,2},paths{i,1},5,lrad);
    
%     % CODE FOR SAVING MARKED-UP IMAGES SHOWING L.E. ROI's%%%%%%%%%%%%%%%%%
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     % while we are at it, go to the 'mask' directory and save marked up
%     % versions of both the channel 1 and 2 data 
%     % first, go to the 'mask' directory
%     cd(mask_dir)
%     % channel 1 data first %%%%%%%%%%%
%     figure(3)
%     hold on
%     imshow(I,[]);
%     %plot(paths{i,2}(:,2),paths{i,2}(:,1),'cyan');
%     for l=1:paths{i,1}
%         rectangle('Position',[normals{l,2}(1)-1 normals{l,1}(1) 2 2],'Curvature',[1 1],'EdgeColor','cyan');
%         rectangle('Position',[normals{l,2}(normals{l,3})-1 normals{l,1}(normals{l,3}) 2 2],'Curvature',[1 1],'EdgeColor','cyan');
%     end
%     % next, grab the image from the figure
%     F = getframe(gcf);
%     % save the file with a good filename
%     filename = ['CH1_edge_' name1{i} '.jpg'];
%     imwrite(F.cdata,filename);
%     hold off
%     % channel 2 data next %%%%%%%%%%%%%
%     figure(4)
%     hold on
%     %JJ=imadjust(ITWO);
%     %imshow(JJ);
%     imshow(I,[]);
%     %plot(paths{i,2}(:,2),paths{i,2}(:,1),'cyan');
%     for l=1:paths{i,1}
%         rectangle('Position',[normals{l,2}(1)-1 normals{l,1}(1) 2 2],'Curvature',[1 1],'EdgeColor','cyan');
%         rectangle('Position',[normals{l,2}(normals{l,3})-1 normals{l,1}(normals{l,3}) 2 2],'Curvature',[1 1],'EdgeColor','cyan');
%     end
%     % next, grab the image from the figure
%     F = getframe(gcf);
%     % save the file with a good filename
%     filename = ['CH2_edge_' name1{i} '.jpg'];
%     imwrite(F.cdata,filename);
%     hold off
%     % go back home
%     cd(maindir)
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % load information into the kymograph cell arrays
    % channel 1
    kymo1{i,1} = num;
    kymo1{i,2} = paths{i,2};
    % channel 2
    kymo2{i,1} = num;
    kymo2{i,2} = paths{i,2};
    % compute and store the intensity values from around the periphery
    % RDM (5/8/2019) added background subtraction (using mask 'bkmask') 
    [kymo1{i,3},bgd1(i),pbd1(i)] = curvescan(I,normals,num,bkmask);
    [kymo2{i,3},bgd2(i),pbd2(i)] = curvescan(ITWO,normals,num,bkmask);
    
    % use cross-correlation to align the intensity traces in the kymographs
    if i>1
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % use cross correlation (without centering data on 0) of adjacent
        % traces in data channel 1 to align the data in both kymographs
        % (channel 1 AND channel 2)
        [r,lag] = xcorr(kymo2{i-1,3},kymo2{i,3});
        tl(i) = lag(find(r==max(r)));
        % make the lag calculation cumulative
        tl(i) = tl(i) + tl(i-1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    % now store the alginment information in the kymo cell arrays
    kymo1{i,4} = tl(i);
    kymo2{i,4} = tl(i);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot the background and intensity data 
% KS bgd1 is  a vector of the backgroundfrom each image, calculated by
% curvescan, vector whose lenght is a number of frames KS  
% bkmask is the square for the background 
% background first %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
hold on
plot(0,0,'dk');
plot([1:n_fr],bgd1,'ok');
plot([1:n_fr],bgd2,'or');
hold off
 title('Image Background Noise', 'FontSize', 14);
 xlabel('time (frames)', 'FontSize', 10);
 ylabel('background intensity (counts/sec)', 'FontSize', 10);
 grid;
 axis tight;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fit intensity to single exponential decay to characterize photobleaching
    % convert the y-data to log values
    ylog1 = log(pbd1./pbd1(1));
    ylog2 = log(pbd2./pbd2(1));
    % load the x values
    xpb = [0:n_fr-1];
    xpb = xpb';
    % use linear regression to find the best-fit slope of a line that runs
    % through the origin: i.e. y = mx
    % to deal with large slopes, we will calculate slope both ways
    
    % since y = mx, the 'estimator matrix' is just xbg
    % the observation vector is ylog
    % the results are contained in res
    
    % solve for the photobleaching coefficient of channel 1
    pb1res = (xpb'*xpb)\xpb'*ylog1;
    pbfit1 = exp(pb1res.*xpb);
    % solve for the photobleaching coefficient of channel 2
    pb2res = (xpb'*xpb)\xpb'*ylog2;
    pbfit2 = exp(pb2res.*xpb);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
% next plot intensity versus frame number %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
% note the average total signal in each channel and return the value
%avsig1 is the mean of each image %KS 
avsig1 = mean(pbd1);
avsig2 = mean(pbd2);
   
% normalize the intensity vs. frame data for plotting with exp fit
%KS pbd1/2 are the normalized intensities 
pbd1 = pbd1 ./max(pbd1);
pbd2 = pbd2 ./max(pbd2);
%class(pbd1)

%normalize avsig to the new normalized pbd
%avsig1 = mean(pbd1);
%avsig2 = mean(pbd2);
hold on
plot(0,0,'dk');
% plot the data
plot([1:n_fr],pbd1,'ok');
plot([1:n_fr],pbd2,'or');
% plot the exponential fits
plot([1:n_fr],pbfit1);
plot([1:n_fr],pbfit2);
hold off
 title('Background-Subtracted Signal Intensity', 'FontSize', 14);
 xlabel('time (frames)', 'FontSize', 10);
 ylabel('signal intensity (counts/sec)', 'FontSize', 10);
 grid;
 axis tight;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
% how much do we stretch the time axis on kymograph image?
strch = 5;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cd(resultsdir)
%ch1kymograph = kymimage(kymo1,strch,ch1_max);
ch1kymograph = kymimage(kymo1,strch,I4);
%normalize to input max intensity KS changed this to ch1_max inputs 
%ktemp1 = 256*(ch1kymograph./ch1_max);
ktemp1 = 256*(ch1kymograph./I4);
% make custom color map
pmap1=jet(128);
pmap2=hot(256);
pmap2=flipud(pmap2);
cmap=[pmap1(1:80,:);pmap2(64:239,:)];
% cmap = hsv(256);
% save the file with a good filename
filename = ['CH1_kymo.tif'];
imwrite(ktemp1,cmap,filename);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ch2kymograph = kymimage(kymo2,strch,I5);
%ch2kymograph = kymimage(kymo2,strch,ch2_max);
%normalize to input max intensity
%ktemp2 = 256*(ch2kymograph./ch2_max);
ktemp2 = 256*(ch2kymograph./I5);
% make custom color map
pmap1=jet(128);
pmap2=hot(256);
pmap2=flipud(pmap2);
cmap=[pmap1(1:80,:);pmap2(64:239,:)];
%cmap = hsv(256);
% save the file with a good filename
filename = ['CH2_kymo.tif'];
imwrite(ktemp2,cmap,filename);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% draw scatter plot of two-channel correlation %%%%%%%%%%%%%%%%%%%%%%%%
% normalize the kymographs so they have the same mean %%%%%%%%%%%%%%%%%
%first cast all the kymo values on a scale from 0 to 1
%exponent1=sprintf('%e' , avsig1)
%split = strsplit(exponent1,'e'); % Split the string where 'e' is
%split2 = str2double(split(2)); % Get the 2nd part after 'e'
%normalize everythign to the max or mean value? not sure yet. KS
%normch1kymo= max(ch1kymograph, [], 'all');
%normch2kymo= max(ch2kymograph, [], 'all');

%ch1kymograph= ch1kymograph ./ normch1kymo;
%ch2kymograph= ch2kymograph ./ normch2kymo;



%this isnt working 
%if (avsig2<= avsig1);
%   rat=(avsig1/avsig2);
%   pbd2=(pbd2 .* rat);
%else rat2=avsig2/avsig1
%   pbd1=(pbd1 .* rat2);
%end 

% KS Normalization 
ch1k=ch1kymograph(:);
ch2k=ch2kymograph(:);
ch1k=ch1k/avsig1;
ch2k=ch2k/avsig2;
xmean=mean(ch1k);
ch1k=ch1k/xmean;
ch2k=ch2k/xmean;

% calculate the 95% maximum signal of the two channels
SK1 = sort(ch1k);
SK2 = sort(ch2k);
% maximum signal
%int95_1 = max(ch1k);
%int95_2 = max(ch2k);
 %95th percentile signal
 int95_1 = SK1(floor(0.95*length(SK1))); 
 int95_2 = SK2(floor(0.95*length(SK2)));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% do a linear fit to the scatter plot
% count the number of data points
nscat = length(ch1k);
% calculate the estimator matrix
Escat = [ch1k ones(nscat,1)];
% solve for the slope and intercept
MBscat = (Escat'*Escat)\Escat'*ch2k;
Yfit = MBscat(1)*ch1k+MBscat(2);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculate R-squared for the fit
% first compute the means of the data
Ymean = mean(ch2k);
Xmean = mean(ch1k);
% sum the regression errors
SSreg = (ch2k-Yfit)'*(ch2k-Yfit);
% sum the total errors
SSavg = (ch2k-Ymean)'*(ch2k-Ymean);
% what fraction of the signal can be explained by the regression
Rsq = 1-SSreg/SSavg;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% now plot everything
figure;
hold on 
plot(ch1k,ch2k,'ok');
 title('Scatter-plot of data from Channels 1 and 2', 'FontSize', 14);
 xlabel('Channel 1 intensity', 'FontSize', 10);
 ylabel('Channel 2 intensity', 'FontSize', 10);
 grid;
 axis tight;
%%new code%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
plot(ch1k,Yfit,'color','black','LineWidth',1)
plot(0:int95_1,0:int95_1,'color','black','LineWidth',2)
% add some info to the figure
str1 = ['Channel 1 mean: ',num2str(Xmean)];
str2 = ['Channel 2 mean: ',num2str(Ymean)];
str3 = ['Slope of regression: ',num2str(MBscat(1))];
str4 = ['R-squared: ',num2str(Rsq)];
tallness = floor(0.75*int95_1);
%tallness = 100;
hpt1 = text(25,tallness+75,str1);
hpt2 = text(25,tallness+50,str2);
hpt3 = text(25,tallness+25,str3);
hpt4 = text(25,tallness,str4);
% release the hold and end the figure
hold off
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% merge both kymographs into one %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ktemp1 = ceil(ktemp1);
ktemp2 = ceil(ktemp2);
kch1RGB = ind2rgb(ktemp1,cmap);
kch2RGB = ind2rgb(ktemp2,cmap);
% make a scale bar with tic marks to go under the kymographs
tottime = strch*n_fr;
blstrip = ones(50,tottime,3);
botstrip = blstrip;
botstrip(10:13,:,:) = 0;
botstrip(10:30,1:3,:) = 0;
botstrip(10:30,tottime-2:tottime,:) = 0;
botstrip(10:30,floor(tottime/2)-1:floor(tottime/2)+1,:) = 0;
botstrip(10:25,floor(tottime/4),:) = 0;
botstrip(10:25,floor(3*tottime/4),:) = 0;
% now add white strips to the top and axes to the bottom of the kymos
kch1RGB = [blstrip; kch1RGB; botstrip];
kch2RGB = [blstrip; kch2RGB; botstrip];
h1=size(kch1RGB);
% merge the kymographs and add margins to the left and right
blstrip = ones(h1(1),25,3);
mergekymo = [blstrip blstrip kch1RGB blstrip kch2RGB blstrip blstrip];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% merge kymographs with cell boundary image
h1=size(mergekymo);
% remember 'pimage' from earlier?
h2=size(pimage);
if h1(1)>h2(1)
    blstrip = ones(h1(1)-h2(1),h2(2),3);
    pimage = [pimage; blstrip];
elseif h1(1)<h2(1)
    blstrip = ones(h2(1)-h1(1),h1(2),3);
    mergekymo = [mergekymo; blstrip];
end
tallness = max(h1(1),h2(1));
mergekymo = [pimage mergekymo];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% KS add some info to the figure, here you can add the average intensity KS
str1 = ['Channel 1 intensity (avg): ',num2str(avsig1)];
str2 = ['Channel 2 intensity (avg): ',num2str(avsig2)];
str3 = ['Channel 1 photobleaching rate: ',num2str(pb1res)];
str4 = ['Channel 2 photobleaching rate: ',num2str(pb2res)];
% make a new figure with the merged kymograph
figure;
imshow(mergekymo);
hpt1 = text(25,tallness-100,str1);
hpt2 = text(25,tallness-75,str3);
hpt3 = text(25,tallness-50,str2);
hpt4 = text(25,tallness-25,str4);
% now save the merged kymograph
filename = ['CH12merge' outfile_tag '.tif'];
imwrite(mergekymo,filename);
cd(maindir)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save some of the quality control data
filename = ['QCdata_' outfile_tag '.mat'];
save(filename, 'ch1k', 'ch2k', 'bgd1', 'bgd2', 'pbd1', 'pbd2','pb1res','pb2res');
% save kymograph data
filename = ['RAWKYMO_' outfile_tag '.mat'];
save(filename, 'kymo1', 'kymo2');
% save registered (aligned) kymograph images
filename = ['ALNKYMO_' outfile_tag '.mat'];
save(filename, 'ch1kymograph', 'ch2kymograph');
% go home - we are done here
cd(maindir);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

return

end

function backmask = makebkgd(xy1,xy2,inpimage)
% makebkgd - creates a logical image 'backmask' with a rectangular mask
% that selections a region of an image for background subtraction. Two
% opposite corners of the mask region are defined by xy1 to xy2
% 
% xy1 and xy2 - are two opposing corners of the mask region
% inpimage is a reference image with the proper dimensions for the output
% backmask - is an output bw image with the same dimensions as inpimage
% with the rectangular ROI for background subtraction filled in

width = abs(xy2(1)-xy1(1))+1;
height = abs(xy2(2)-xy1(2))+1;

% make a submatrix mask
submx = ones(width,height);
% load the submatrix into a correct-size image to create the full-size
% output mask
x1 = min(xy1(1),xy2(1));
x2 = max(xy1(1),xy2(1));
y1 = min(xy1(2),xy2(2));
y2 = max(xy1(2),xy2(2));
backmask=inpimage.*0;
backmask(x1:x2,y1:y2) = submx;
backmask=logical(backmask);

return
end

function im_kym = kymimage(kym,stretch,imax)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% build a kymograph image from a kymograph data cell array.
% im_kym - is the output image file
% kym - is the input kymograph cell structure
% stretch - is how much to stretch the time dimension
% imax - is the maximum intensity for image scaling

% initialize a few things
% nf is the number of frames in the movie. This algorithm fails if the
% number of frames is fewer than 4 (the number of fields in kym)
nf = length(kym);
% lengths and offsets are track lengths and registration offsets
offsets = zeros(nf,1);
lengths = zeros(nf,1);
% load the lengths and offests into vectors for convenience
for i=1:nf
    lengths(i) = kym{i,1};
    offsets(i) = kym{i,4};
end
% calculate the positions of the top and bottom edges of the kymo
top_edg = min([min(offsets) 0]);
bot_edg = max(lengths+offsets);
% calculate the maximum length needed to hold all of the aligned kymos
width = bot_edg - top_edg;

% initialize the image
im_kym = zeros(width,stretch*nf);

for i=1:nf
    % the commented code centers the lines of the kymo which is a mistake
    %init = 1+floor((width-kymo{i,1})/2);
    for j=1:stretch
        lnst = offsets(i)-top_edg+1;
        im_kym(lnst:lnst+lengths(i)-1,1+(i-1)*stretch+j-1) = kym{i,3};
    end
end
hold off    % just in case

% normalize image data for 256-color plotting
temp = 256*(im_kym./imax);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% make custom color map
% N.B. the old color map was just jet(128). The new one is similar to
% jet(128) but expands the contrast in the low signal region
pmap1=jet(128);
pmap2=hot(256);
pmap2=flipud(pmap2);
cmap=[pmap1(1:80,:);pmap2(64:239,:)];
pmap1=jet(128);
pmap2=hot(256);
pmap2=flipud(pmap2);
cmap=[pmap1(1:80,:);pmap2(64:239,:)];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% new figure
figure;
imshow(temp,[0 256],'colormap',cmap);
colorbar;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
return
end

function [norm] = findnorm(perimIM,npath,npts,smrad,outrad)
% this function uses the matrix 'npath' to navigate around the perimeter
% image 'perimIM' and calculate normal vectors to every point on the
% perimeter. These are returned in the cell structure 'norm'
%
% perimIM
% npath
% npts
% smrad
% outrad

% position 1 holds the columns (y-data) for the kymograph evaluation
% position 2 holds the rows (x-data) for the kymograph evaluation
norm = cell(npts,3);

% run around the perimeter
for i=1:npts
    % set the current point
    xo = npath(i,2);
    yo = npath(i,1);
    
    % pull out a submatrix centered on (xo, yo)
    subtest = perimIM(yo-smrad:yo+smrad,xo-smrad:xo+smrad);
    % identify the perimeter points within the submatrix
    [ys,xs,vs]= find(subtest);
    % center the submatrix points on the origin
    xs = xs-(smrad+1);
    ys = ys-(smrad+1);
    
    % use linear regression to find the best-fit slope of a line that runs
    % through the origin: i.e. y = mx OR x = my
    % to deal with large slopes, we will calculate slope both ways
    
    % since y = mx, the 'estimator matrix' is just xs
    % the observation vector is ys
    % the results are contained in res
    
    % solve for the best fit coefficient with x as the independent variable
    xres = (xs'*xs)\xs'*ys;
    % solve for best fit coefficient with y as the independent variable
    yres = (ys'*ys)\ys'*xs;
    
    % N.B. To find a normal to the tangent we just invert the slope and
    % multiply by -1. The trick here is that the y-based slope is the
    % inverse of the x-based slope
    
    % choose the smaller of the two slopes to calculate the points that lie
    % on the normal line: this avoids problems with infinite slopes:
    % if the x-based slope is larger, then use the y-based slope...
    if abs(xres) > abs(yres) || isnan(xres)
        % do the calculation right
        yso = [-outrad:outrad]';
        xso = round(yres*yso);
        % then rotate the result by 90 degrees to create a normal
        norm{i,1} = -xso + yo;
        norm{i,2} = yso + xo;
    % similarly, if the y-based slope is larger...    
    else
        % do the calculation right
        xso = [-outrad:outrad]';
        yso = round(xres*xso);
        % then rotate the result by 90 degrees to create a normal
        norm{i,1} = -xso + yo;
        norm{i,2} = yso + xo;
    end
    % by using the negative of the reciprocal slopes we automatically
    % rotate the tangent vector by 90 degrees to create the normal vector
    
    % finally, save the number of points in the normal vector
    norm{i,3} = length(norm{i,1});
    
end

return
end

function [intens,bgp,pbp] = curvescan(image,norms,npts,bi)
% this function computes the maximum intensity values along a set of normal
% vectors defined on a grayscale image.

% intens - is the output vector containing the measured intensities
% bgp - is the average background intensity for this image
% pbp - is the total background-subtracted intensity of the image
%
% image - is the original 2D imaging data
% norms - is a cell array containing x and y values of normals at each
%         point on the curve 
% npts - is the number of points in the perimeter line
% bi - is a binary image mask used to compute a background correction

% calculate the background and then subtract it from the image
temp = uint16(bi).*image;

bgp = floor(sum(temp,'all')/sum(bi,'all'));
image = image - bgp;
% compute total background-subtracted intensity
pbp = sum(image,'all');

% initialize the output parameter
intens = zeros(npts,1);

% run around the curve and compute the intensities
for i=1:npts
    vals = zeros(norms{i,3},1);
    for j=1:norms{i,3}
        vals(j) = image(norms{i,1}(j),norms{i,2}(j));
    end
    intens(i) = max(vals);
end

return

end