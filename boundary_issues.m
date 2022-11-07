function bdy_img = boundary_issues(imgdir,thresh,blur)
%blur should be 5, thresh should start at 0.005
% bdy_issues() - This function identifies the edges of a cell in a set of
% time-lapse images, based on the fluorescence of a labeled protein. 
% adapted from 'pathfinder()' by RDM 5/6 /2019
%
% imgdir - is the directory that contains the timelapse image sequence  
% name - is a vector of name suffixes for reconstrucitng file names
% forename - is the name prefix for reconstructing file names
% thresh - is the threshold used to discriminate objects from noise
% blur - is the degree of gaussian blurring to perform on initial image

% set the return directory to the current one
ret_dir = pwd;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get_image_names() goes to the image directory; extracts the names of all 
% the .tif images; and parses them so that they can be recoded later.
% 'name' is a cell array ontaining the last three characters of all the
% image names and 'forename' contains the all but the last three characters
% of the name. 
[name,forename] = get_image_names(imgdir);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% count the number of frames
n_fr = length(name);

% lwid - is the width of the region of interest at the cell edge
lwid = 20;
lrad = floor(lwid/2);

cd(imgdir)
% run through all the frames in the directory, find the edge, and build the
% color-coded boundary image
for i=1:n_fr

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % here we open the image and do some basic processing
    % load the image from the directory
    I = imread([forename,name{i}]);
    % blur the image a bit
    I2 = imgaussfilt(I,blur);
    % Median Filter
    I3 = medfilt2(I2,[1 1]);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % the bw variables hold sequential, processed versions of the original
    % image. The first step (bw) sets a threshold
    % the second step (bw2) fills in any 'holes' in the image
    % the third step (bw3) determines the size of the blobs kept
    % the fourth step (bw4) creates a (smoothed?) perimeter around every image
    % the fifth step (bw5) fills the perimeters back in
    bw = im2bw(I3,thresh);
    bw2 = imfill(bw,'holes');    
    % may not need to use bwareaopen but bw3 and bw4_perim are the two most 
    % useful bw images for analysis
    bw3 = bwareaopen(bw2,100); 
    bw4_perim = bwperim(bw3);  
    
    % add the new ROI outline to the existing figure 1
    if i==1
        bdy_img = bw4_perim;
    else
        bdy_img = bdy_img + bw4_perim;
    end
    
end
cd(ret_dir)

bdy_img=imcomplement(bdy_img);
figure(5)
imshow(bdy_img);

return
end

