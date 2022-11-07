New version of dynamic region of interest determination function that
identifies the perimeter of a cell and follows protein dynamics in two
channels around a user-defined segment of this perimeter. Input includes 
the names of two directories that contain two numbered sequences of .tif 
images of two fluorescent proteins. The perimeter and region of interest 
are defined using from the first channel (raw_ch1). Output includes a 
pair of kymographs computed on the same dynamically defined regions of 
interest for both image sequences. 
This code calls the following accessory functions:
generic_edge2() 
get_image_names();

copyright 2016, RDM and KC
adapted and expanded 2019, RDM and KC
further revised 2022, RDM and KS

This version analyzes two color time-lapse data sets. First it uses the 
marker fluorescence of images in raw_ch1 to identify the cell edge and, 
with user input, creates a dynamic region of interist around the cell
edge. Using this region of interest the program creates a kymograph for 
the original channel and a second, independent channel. 

RDM - 5/6/2019
CHANGES FROM DROID4: the main change is that the code first displays an
overlaid set of cell boundaries detected by the algorithm: bdy_issue().
This overlay image is used to select the endpoints of the dynamic region
of interest. In addition, a background region is selected and used to
perform a background subtraction on each image. The code also now
computes and displays data on background and signal intensity throughout
the time-lapse sequence to check for illumination fluctuations and
photobleaching. Finally, the two kymographs are displayed together with
the boundary image overlay and use-defined ROIs. 

KS - 11/7/2022
Prior to import, images must be background subtracted, thresholded and any area outside the cell must be zeroed. A fiji script is included (NAME HERE) to prepare the images. 