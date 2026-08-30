
%% ============================================================
%  1) FUNCTION CREATION
%% ============================================================

% -------- FUNCTION --------

function [MaskCluster] = CreateMaskCluster(folder, file, showFigure, dilationRadius, marginRadius)

% -------- IF CONDITION --------

if nargin < 3       % if no 3rd argument, then false
    showFigure = false;
end

%% ============================================================
%  1) IMAGE LOADING
%% ============================================================

% -------- IMAGE PATH --------

filepath = fullfile(folder, file);

% -------- IMAGE READING -------- (only 1st plane)

I_raw = imread(filepath, 1);

% -------- IMAGE NORMALIZATION -------- (0...1 -> grays)

I = mat2gray(I_raw);

%% ============================================================
%  2) IMAGE PRE-PROCESSING
%% ============================================================

% -------- GAUSSIAN FILTER --------

sigma = 2;
I_gfilt = imgaussfilt(I, sigma);

    % sigma -> the higher, the softer

% -------- BACKGROUND FILTER -------- (not used)

% --- Background Estimation ---

backgroundRadius = 300;
backgroundStrength = 0.05;
background = imopen(I_gfilt, strel("disk", backgroundRadius));

    % radius -> background =  everything bigger than backgroundRadius 
    % strength -> correction strength

% --- Background Subtraction ---

I_bfilt = I_gfilt - backgroundStrength * background;
I_bfilt = mat2gray(I_bfilt);

%% ============================================================
%  3) INITIAL THRESHOLD MASK
%% ============================================================

% -------- OTSU METHOD -------- (binarization)

threshold = graythresh(I_bfilt);  % (background // object)

threshold_CorrectionFactor = 1;
        
    % Increase this value if the mask includes too much background
    % Decrease this value if the mask misses part of the cluster


BW = imbinarize(I_bfilt, threshold * threshold_CorrectionFactor);


%% ============================================================
%  4) MASK CLEANING
%% ============================================================

% -------- CONNECT NEARBY STRUCTURES --------

closingRadius = 8;     
BW_clean = imclose(BW, strel("disk", closingRadius));

     % radius -> maximum distance between the structures to get connected

% -------- FILL INTERNAL HOLES --------

BW_clean = imfill(BW_clean, "holes");

% -------- REMOVE SMALL NOISE -------- (small binary structures)

minObjectSize = 300;
BW_clean = bwareaopen(BW_clean, minObjectSize);

%% ============================================================
%  5) CENTRAL CLUSTER SELECTION
%% ============================================================

% -------- MASK TOTAL ORIGINAL DIMENSION --------

nRows = size(I,1);
nCols = size(I,2);

% -------- REGION OF INTEREST -------- (ROI)

centralFraction = 0.65;

xMin = (1 - centralFraction)/2 * nCols;
xMax = (1 + centralFraction)/2 * nCols;

yMin = (1 - centralFraction)/2 * nRows;
yMax = (1 + centralFraction)/2 * nRows;

% -------- ROI MASK -------- (just in case we have larger clusters)

% --- 0 Matrix with proper dimensions ---

ROI = false(size(BW_clean));

% --- Central Region --- (Pixel of BW_clean true if ROI)

ROI(round(yMin):round(yMax), ...
    round(xMin):round(xMax)) = true;

BW_ROI = BW_clean & ROI;

% -------- MASK CLEANING -------- (just in case because of the cropping)

BW_ROI = imclose(BW_ROI, strel("disk", 10));
BW_ROI = imfill(BW_ROI, "holes");
BW_ROI = bwareaopen(BW_ROI, 500);

% -------- LARGER CLUSTER SELECTION -------- (in the ROI)

% --- Objects Detection ---

CC = bwconncomp(BW_ROI);

% --- Objects Properties ---

stats = regionprops(CC, "Area", "PixelIdxList");

% --- Larger Object Detection ---

[~, largestIdx] = max([stats.Area]);


% --- Mask Creation ---

MaskCluster = false(size(BW_ROI));
MaskCluster(stats(largestIdx).PixelIdxList) = true;

%% ============================================================
%  6) EXPAND MASK
%% ============================================================

% -------- OUTWARD EXPANSION --------

% dilationRadius = 25;

MaskCluster = imdilate( ...
    MaskCluster, ...
    strel("disk", dilationRadius));

% -------- SMOOTH BORDERS --------

MaskCluster = imclose( ...
    MaskCluster, ...
    strel("disk", 8));

% -------- FILL INTERNAL HOLES --------

MaskCluster = imfill(MaskCluster, "holes");

% -------- EXTRA MARGIN -------- (pixels)

% marginRadius = 100;

MaskCluster = imdilate( ...
    MaskCluster, ...
    strel("disk", marginRadius));

%% ============================================================
%  8) SHOW FINAL OVERLAY
%% ============================================================

if showFigure

    figure

    imshow(I, [])
    hold on

    visboundaries(MaskCluster, ...
        "Color", "r", ...
        "LineWidth", 1);

    title("Final Mask Overlay")

end









