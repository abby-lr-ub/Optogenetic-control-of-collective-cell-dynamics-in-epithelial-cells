%% ============================================================
%  0) RESET WORKSPACE AND FIGURE STYLE
%% ============================================================

reset(groot)
clearvars
close all
clc

set(groot,'defaultFigureWindowStyle','docked')

set(groot,'defaultAxesXColor','k')
set(groot,'defaultAxesYColor','k')
set(groot,'defaultTextColor','k')
set(groot,'defaultColorbarColor','k')

set(groot,'defaultAxesFontWeight','bold')
set(groot,'defaultTextFontWeight','bold')

set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')


%% ============================================================
%  0b) FIGURE SIZE AND FONTS  (single source of truth)
%% ============================================================

dockFigures    = false;

figSize_px     = [750 600];    % single-panel figures and the profile movie
figSizeMap_px  = [900 750];    % per-cell q map movie (taller: image aspect)

fontSizeAxes   = 24;
fontSizeLegend = 22;

set(groot,'defaultAxesFontSize',fontSizeAxes)
set(groot,'defaultTextFontSize',fontSizeAxes)
set(groot,'defaultLegendFontSize',fontSizeLegend)
set(groot,'defaultColorbarFontSize',fontSizeAxes)

if dockFigures
    set(groot,'defaultFigureWindowStyle','docked')
else
    set(groot,'defaultFigureWindowStyle','normal')
end


%% ============================================================
%  1) DATA LOADING, SAMPLE STRUCTURE AND PARAMETERS
%% ============================================================

% -------- INPUT FOLDER --------

dataFolder = 'Data';


% -------- RESULTS FOLDER --------

resultsFolder = fullfile('Results','ShapeAnalysis');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

% -------- DATA LOADING --------

MBI_file_name = "F97V_CloneD1_optoRhoA_day6_Again-01-MBI.mat";
load(fullfile(dataFolder, MBI_file_name));

Segmentation_file_name = "Segmentation.mat";
load(fullfile(dataFolder, Segmentation_file_name));

% -------- NUMBER OF POSITIONS --------

nFiles = 24;

% -------- POSITION GROUPS --------
% Pos01 - Pos12  --> ACTV
% Pos13 - Pos24  --> Ctrl

nActv = 12;
nCtrl = 12;

idxActv = 1:12;
idxCtrl = 13:24;

% -------- ACTIVATION REGION --------
% LabelMatrix is in rescaled Cellpose pixels.
% Activation region is a vertical stripe of 150 um width.

rescalingFactor = 0.5324;       % um per pixel in LabelMatrix

stripeWidth_um = 150;           % total stripe width in um 
stripeWidth_px = stripeWidth_um / rescalingFactor;
stripeHalfWidth_px = stripeWidth_px / 2;


% -------- TIME WINDOWS --------
%   0  - 2 h   : Control / basal
%   2  - 12 h  : ACTV
%   12 - 16 h  : Control / recovery

frameDuration_min = 3;

preControl_h = 2;
activation_h = 10;
postControl_h = 4;

activationStartTime = preControl_h;                                  % 2 h
activationEndTime   = preControl_h + activation_h;                   % 12 h
experimentEndTime   = preControl_h + activation_h + postControl_h;   % 16 h

activationStartFrame = round(activationStartTime * 60 / frameDuration_min);  % 40
activationEndFrame   = round(activationEndTime   * 60 / frameDuration_min);  % 240
experimentEndFrame   = round(experimentEndTime   * 60 / frameDuration_min);  % 320

% -------- EXAMPLE POSITIONS FOR VISUAL CHECK --------

exampleFiles = [8];     % one ACTV, one Ctrl
exampleFrame = activationStartFrame + 120;

% -------- DISPLAY OPTIONS --------
% showOutside = true also draws, as DASHED lines, the cells OUTSIDE
% the stripe: same field, same schedule, but no blue light. It is the
% internal control of the experiment.

showOutside = true;

%% ============================================================
%  2) GENERATE FILE NAMES
%% ============================================================

fileNames = strings(nFiles,1);

for i = 1:nFiles
    fileNames(i) = sprintf('LabelMatrix_Pos%02d.mat', i);
end

%% ============================================================
%  3) VISUAL CHECK OF ACTIVATION STRIPE
%% ============================================================

controlColor = [1 0.3 0.2];
actvColor    = [0.2 0.4 1];

for e = 1:length(exampleFiles)

    exampleFile = exampleFiles(e);

    data = load(fullfile(dataFolder, fileNames(exampleFile)));

    if isfield(data,'LabelMatrix')
        LabelMatrix = data.LabelMatrix;
    else
        fn = fieldnames(data);
        LabelMatrix = data.(fn{1});
    end

    L = LabelMatrix(:,:,exampleFrame);

    % -------- Rotate 90 deg counter-clockwise --------
    % The stripe center comes from MBI.Regions in the ORIGINAL frame,
    % so the original width is stored before rotating.

    imageWidth0 = size(L,2);

    L = rot90(L);

    imageHeight = size(L,1);        % = original width
    imageWidth  = size(L,2);        % = original height

    % -------- Correct stripe center from MBI.Regions --------

    Region = MBI.Regions([MBI.Regions.InPosition] == exampleFile);

    if isempty(Region)
        error('No MBI.Regions entry found for position %d', exampleFile)
    else
        Region = Region(1);
    end

    xCenter = Region.RelXinPosition;

    stripeCenterX0 = imageWidth0/2 + xCenter;      % original frame

    % Under rot90 a point (x,y) maps to (y, W0+1-x), so the vertical
    % stripe becomes a HORIZONTAL band.

    stripeCenterY_example = imageWidth0 + 1 - stripeCenterX0;

    stripeYMin_example = max(1,           stripeCenterY_example - stripeHalfWidth_px);
    stripeYMax_example = min(imageHeight, stripeCenterY_example + stripeHalfWidth_px);

    % -------- Build RGB label image and boundaries --------

    RGB = label2rgb(L,'jet','k','shuffle');
    B = boundarymask(L);

    % -------- Create figure matched to the rotated image --------

    imAspect = imageWidth / imageHeight;

    hFig = newFigure(['Activation stripe check Pos' num2str(exampleFile)], ...
                     [round(figSize_px(2)*imAspect) figSize_px(2)], dockFigures);

    ax = axes('Parent', hFig);
    imshow(RGB, 'Parent', ax, 'InitialMagnification', 'fit', 'Border', 'loose');
    axis(ax, 'image')
    hold(ax, 'on')

    % -------- Boundaries --------

    [y,x] = find(B);
    plot(ax, x, y, '.', 'Color','w', 'MarkerSize',1)

    % -------- Detect cells inside activation stripe --------

    stats = regionprops(L, 'Centroid', 'Area');

    if ~isempty(stats)

        centroids = cat(1,stats.Centroid);
        areas_px2 = [stats.Area]';

        validCells = areas_px2 > 0;

        % The band is horizontal now: test the SECOND coordinate.
        cellsIn = centroids(:,2) >= stripeYMin_example & ...
                  centroids(:,2) <= stripeYMax_example & ...
                  validCells;

        plot(ax, centroids(cellsIn,1), centroids(cellsIn,2), ...
            'go', 'MarkerSize',4, 'LineWidth',1)
    end

    % -------- Horizontal activation stripe --------

    patch('Parent', ax, ...
        'XData',[1 imageWidth imageWidth 1], ...
        'YData',[stripeYMin_example stripeYMin_example ...
                 stripeYMax_example stripeYMax_example], ...
        'FaceColor','r', ...
        'FaceAlpha',0.15, ...
        'EdgeColor',actvColor, ...
        'LineWidth',5, ...
        'Clipping','on');

    % -------- Condition label --------

    if ismember(exampleFile, idxCtrl)
        conditionLabel = 'Control';
    elseif ismember(exampleFile, idxActv)
        conditionLabel = 'ACTV';
    else
        conditionLabel = 'Unknown';
    end

    % -------- Scale bar --------

    scaleBar_um = 100;
    scaleBar_px = scaleBar_um / rescalingFactor;

    barHeight  = 0.02 * imageHeight;

    barMarginX = 0.04 * imageWidth;
    barMarginY = 0.09 * imageHeight;

    xBar = imageWidth  - barMarginX - scaleBar_px;
    yBar = imageHeight - barMarginY;

    % Background box: drawn FIRST so it sits behind bar and label
    boxPad = 0.015 * imageWidth;
    boxW   = scaleBar_px + 2*boxPad;
    boxH   = 4*barHeight + 2*boxPad;

    boxX = xBar - boxPad;
    boxY = yBar - barHeight - boxPad;

    patch('Parent', ax, ...
        'XData',[boxX, boxX+boxW, boxX+boxW, boxX], ...
        'YData',[boxY, boxY, boxY+boxH, boxY+boxH], ...
        'FaceColor','k', ...
        'FaceAlpha',0.65, ...
        'EdgeColor','none');
    % Bar
    rectangle('Parent', ax, ...
        'Position',[xBar, yBar-barHeight, scaleBar_px, barHeight], ...
        'FaceColor','w', 'EdgeColor','none');

    % Label (no BackgroundColor: the box already provides it)
    text(ax, xBar + scaleBar_px/2, yBar + 0.6*barHeight, ...
         [num2str(scaleBar_um) ' $\mu$m'], ...
         'Color','w', 'FontSize',18, 'FontWeight','bold', ...
         'HorizontalAlignment','center', 'VerticalAlignment','top');

    hold(ax, 'off')
    drawnow

    % -------- Save figure --------

    saveCurrentFigure(hFig, resultsFolder, ...
        sprintf('Check_Pos%02d', exampleFile));

end


%% ============================================================
%  4) MAIN ANALYSIS LOOP
%% ============================================================

allMeanAR_in    = [];
allMeanAR_out   = [];

allMeanPval_in  = [];
allMeanPval_out = [];

allMeanArea_in  = [];
allMeanArea_out = [];

allN_in  = [];
allN_out = [];

% -------- WHOLE FIELD OF VIEW --------
%
% In the Control positions the stripe is virtual (MBI coordinates only,
% no blue light), so its inside and outside are indistinguishable. The
% Control baseline is therefore taken over the WHOLE cleaned field of
% view. Filled for every position, used only for the Control columns.

allMeanAR_fov   = [];
allMeanPval_fov = [];
allMeanArea_fov = [];
allN_fov        = [];

% -------- EFFECTIVE AREAS FOR THE CELL DENSITY --------
% Filled inside the main loop (section 4.2b), one value per position.

validArea_in_um2  = nan(nFiles,1);
validArea_out_um2 = nan(nFiles,1);
validArea_fov_um2 = nan(nFiles,1);

% -------- SPATIAL PROFILE PARAMETERS --------
% shape index / area vs signed distance to the stripe center, binned
% inside the main loop to avoid a second load + regionprops pass.

profileAxis       = 'x';    % 'x' -> perpendicular to the stripe (recommended)
                            % 'y' -> along the stripe (control, should be flat)

binWidth_um       = 20;     % spatial bin width (um)
maxDist_um        = 200;    % profile range: -maxDist .. +maxDist (um)

minCellsPerBin    = 3;      % discard a position/frame bin below this count
timeSmooth_frames = 5;      % moving average over frames (1 = no smoothing)

makeVideo         = true;
videoFrameRate    = 20;
% -------- EDGE EXCLUSION --------
% Cells whose centroid is closer than this margin to any border are
% discarded: the frame truncates them and inflates their shape index.

edgeMargin_um = 16;                             % ~ half a cell diameter
edgeMargin_px = edgeMargin_um / rescalingFactor;

% -------- BIN DEFINITION --------

edges_um      = -maxDist_um : binWidth_um : maxDist_um;
binCenters_um = edges_um(1:end-1) + binWidth_um/2;
nBins         = numel(binCenters_um);

% Profile accumulators are allocated once Tref is known (inside f == 1).
sumPval_prof = [];
sumArea_prof = [];
cnt_prof     = [];


for f = 1:nFiles

    fprintf('Processing %s...\n', fileNames(f));


    %% ------------------------------------------------------------
    %  4.1) Load label matrix
    %% ------------------------------------------------------------

    data = load(fullfile(dataFolder, fileNames(f)));

    if isfield(data,'LabelMatrix')
        LabelMatrix = data.LabelMatrix;
    else
        fn = fieldnames(data);
        LabelMatrix = data.(fn{1});
    end

    T = size(LabelMatrix,3);

    imageHeight = size(LabelMatrix,1);
    imageWidth  = size(LabelMatrix,2);


    %% ------------------------------------------------------------
    %  4.2) Correct activation stripe from MBI.Regions
    %% ------------------------------------------------------------

    Region = MBI.Regions([MBI.Regions.InPosition] == f);

    if isempty(Region)
        error('No MBI.Regions entry found for position %d', f)
    else
        Region = Region(1);
    end

    xCenter = Region.RelXinPosition;

    stripeCenterX_f = imageWidth/2 + xCenter;

    stripeXMin_f = max(1, stripeCenterX_f - stripeHalfWidth_px);
    stripeXMax_f = min(imageWidth, stripeCenterX_f + stripeHalfWidth_px);

    stripeCenterY_f = imageHeight/2;   % the stripe spans the whole image height


    %% ------------------------------------------------------------
    %  4.2b) Effective areas used for the cell density
%
%  Cells closer than edgeMargin_px to a border are discarded in 4.5, so
%  the contributing area is the image shrunk by that margin, not the
%  full field of view. Inside = stripe within the valid region;
%  outside = the rest of it.
    %% ------------------------------------------------------------

    xValidMin = edgeMargin_px;
    xValidMax = imageWidth  - edgeMargin_px;
    yValidMin = edgeMargin_px;
    yValidMax = imageHeight - edgeMargin_px;

    heightValid_px = max(0, yValidMax - yValidMin);
    widthValid_px  = max(0, xValidMax - xValidMin);

    % Portion of the activation stripe that survives the edge margin
    xInMin = max(stripeXMin_f, xValidMin);
    xInMax = min(stripeXMax_f, xValidMax);

    widthIn_px  = max(0, xInMax - xInMin);
    widthOut_px = max(0, widthValid_px - widthIn_px);

    validArea_in_um2(f)  = widthIn_px  * heightValid_px * rescalingFactor^2;
    validArea_out_um2(f) = widthOut_px * heightValid_px * rescalingFactor^2;

% Whole valid field of view: reference area for the Control density.
    validArea_fov_um2(f) = widthValid_px * heightValid_px * rescalingFactor^2;


    %% ------------------------------------------------------------
    %  4.3) Initialize global matrices after first file
    %% ------------------------------------------------------------

    if f == 1

        Tref = T;

        allMeanAR_in    = nan(Tref,nFiles);
        allMeanAR_out   = nan(Tref,nFiles);

        allMeanPval_in  = nan(Tref,nFiles);
        allMeanPval_out = nan(Tref,nFiles);

        allMeanArea_in  = nan(Tref,nFiles);
        allMeanArea_out = nan(Tref,nFiles);

        allN_in  = nan(Tref,nFiles);
        allN_out = nan(Tref,nFiles);

        allMeanAR_fov   = nan(Tref,nFiles);
        allMeanPval_fov = nan(Tref,nFiles);
        allMeanArea_fov = nan(Tref,nFiles);
        allN_fov        = nan(Tref,nFiles);

        % Spatial profile accumulators [nBins x Tref x nFiles]
        sumPval_prof = zeros(nBins, Tref, nFiles);
        sumArea_prof = zeros(nBins, Tref, nFiles);
        cnt_prof     = zeros(nBins, Tref, nFiles);

    else

        if T ~= Tref
            error(['File ' char(fileNames(f)) ' has a different number of frames.'])
        end

    end

    %% ------------------------------------------------------------
    %  4.4) Initialize temporary vectors for this position
    %% ------------------------------------------------------------

    meanAR_in    = nan(T,1);
    meanAR_out   = nan(T,1);

    meanPval_in  = nan(T,1);
    meanPval_out = nan(T,1);

    meanArea_in  = nan(T,1);
    meanArea_out = nan(T,1);

    n_in  = nan(T,1);
    n_out = nan(T,1);

    meanAR_fov   = nan(T,1);
    meanPval_fov = nan(T,1);
    meanArea_fov = nan(T,1);
    n_fov        = nan(T,1);

    %% ------------------------------------------------------------
    %  4.5) Loop through time frames
    %% ------------------------------------------------------------

    for t = 1:T

        L = LabelMatrix(:,:,t);

        stats = regionprops(L, ...
            'Centroid', ...
            'MajorAxisLength', ...
            'MinorAxisLength', ...
            'Area', ...
            'Perimeter');

        if isempty(stats)
            continue
        end


        % -------- Extract cell measurements --------

        centroids = cat(1,stats.Centroid);

        majorAxis = [stats.MajorAxisLength]';
        minorAxis = [stats.MinorAxisLength]';

% regionprops areas are in px^2; converted to um^2 below.

        areas_px2 = [stats.Area]';
        areas_um2 = areas_px2 * rescalingFactor^2;

        perimeters_px = [stats.Perimeter]';
        perimeters_um = perimeters_px * rescalingFactor;


        % -------- Compute aspect ratio, shape index and valid-cell masks --------
        % AR : aspect ratio (major / minor axis)
        % P  : structural / shape index (perimeter / sqrt(area))

        AR = majorAxis ./ minorAxis;
        P  = perimeters_px ./ sqrt(areas_px2);

        validAR = areas_px2 > 0 & ...
            minorAxis > 0 & ...
            isfinite(AR);

        validP = areas_px2 > 0 & ...
            perimeters_px > 0 & ...
            isfinite(P);

        validArea = areas_um2 > 0 & ...
            isfinite(areas_um2);


        % -------- Discard cells too close to the field-of-view edges --------
% Their shapes are truncated by the frame, which inflates the shape
% index. Folded into every validity mask so it propagates to the
% in/out means, the counts and the spatial profile alike.

        nearEdge = centroids(:,1) < edgeMargin_px | ...
                   centroids(:,1) > imageWidth  - edgeMargin_px | ...
                   centroids(:,2) < edgeMargin_px | ...
                   centroids(:,2) > imageHeight - edgeMargin_px;

        validAR   = validAR   & ~nearEdge;
        validP    = validP    & ~nearEdge;
        validArea = validArea & ~nearEdge;


        % -------- Classify cells inside or outside activation stripe --------
% Vertical stripe: inside = centroid x within the stripe limits.

        cellsIn = centroids(:,1) >= stripeXMin_f & ...
            centroids(:,1) <= stripeXMax_f;

        cellsOut = ~cellsIn;


        % -------- Store mean AR, mean shape index, mean area and cell counts --------
% AR and P are dimensionless; area is stored in um^2.

        meanAR_in(t)  = mean(AR(validAR & cellsIn),'omitnan');
        meanAR_out(t) = mean(AR(validAR & cellsOut),'omitnan');

        meanPval_in(t)  = mean(P(validP & cellsIn),'omitnan');
        meanPval_out(t) = mean(P(validP & cellsOut),'omitnan');

        meanArea_in(t)  = mean(areas_um2(validArea & cellsIn),'omitnan');
        meanArea_out(t) = mean(areas_um2(validArea & cellsOut),'omitnan');

        n_in(t)  = sum(validAR & cellsIn);
        n_out(t) = sum(validAR & cellsOut);


        % -------- Same quantities over the WHOLE field of view --------
%
% No inside/outside split: every valid cell of the frame enters the
% average. Used as the Control baseline. This is NOT the mean of the
% inside and outside means, but the true per-cell average, so it is
% automatically weighted by the cells each region contains.

        meanAR_fov(t)   = mean(AR(validAR),'omitnan');
        meanPval_fov(t) = mean(P(validP),'omitnan');
        meanArea_fov(t) = mean(areas_um2(validArea),'omitnan');

        n_fov(t) = sum(validAR);


        % -------- Accumulate spatial profile (shape index & area) --------
% Signed distance of each cell to the stripe center (um), binned for
% the spatial profiles of section 11. Reuses the centroids, P, areas
% and validP already computed, so it is edge-cleaned too.

        if strcmpi(profileAxis,'x')
            d_um = (centroids(:,1) - stripeCenterX_f) * rescalingFactor;
        else
            d_um = (centroids(:,2) - stripeCenterY_f) * rescalingFactor;
        end

        b  = discretize(d_um, edges_um);      % NaN outside the range
        okProf = validP & ~isnan(b);          % same validity as the shape index

        if any(okProf)
            sumPval_prof(:,t,f) = accumarray(b(okProf), P(okProf),         [nBins 1], @sum, 0);
            sumArea_prof(:,t,f) = accumarray(b(okProf), areas_um2(okProf), [nBins 1], @sum, 0);
            cnt_prof(:,t,f)     = accumarray(b(okProf), 1,                 [nBins 1], @sum, 0);
        end

    end

    %% ------------------------------------------------------------
    %  4.6) Store results from this position
    %% ------------------------------------------------------------

    allMeanAR_in(:,f)  = meanAR_in;
    allMeanAR_out(:,f) = meanAR_out;

    allMeanPval_in(:,f)  = meanPval_in;
    allMeanPval_out(:,f) = meanPval_out;

    allMeanArea_in(:,f)  = meanArea_in;
    allMeanArea_out(:,f) = meanArea_out;

    allN_in(:,f)  = n_in;
    allN_out(:,f) = n_out;

    allMeanAR_fov(:,f)   = meanAR_fov;
    allMeanPval_fov(:,f) = meanPval_fov;
    allMeanArea_fov(:,f) = meanArea_fov;
    allN_fov(:,f)        = n_fov;

end


%% ============================================================
%  5) GROUP DATA BY CONDITION
%% ============================================================

% -------- TIME VECTOR IN HOURS --------
% Frame 1 is represented as 3 minutes, as in the original script.

time = (1:Tref) * frameDuration_min / 60;


% -------- REGIONS USED FOR EACH CONDITION --------
%
% ACTV positions keep the inside / outside split: there the stripe is a
% real physical boundary and the outside is the internal control.
%
% Control positions are averaged over the WHOLE field of view, since
% their stripe is virtual. This roughly triples the number of cells per
% Control point at the price of a wider spatial support.

% -------- ASPECT RATIO --------

Ctrl_AR_fov = allMeanAR_fov(:,idxCtrl);
Actv_AR_in  = allMeanAR_in(:,idxActv);
Actv_AR_out = allMeanAR_out(:,idxActv);

% -------- SHAPE INDEX --------

Ctrl_Pval_fov = allMeanPval_fov(:,idxCtrl);
Actv_Pval_in  = allMeanPval_in(:,idxActv);
Actv_Pval_out = allMeanPval_out(:,idxActv);


% -------- AREA --------
% These variables are now in micrometers^2.

Ctrl_Area_fov = allMeanArea_fov(:,idxCtrl);
Actv_Area_in  = allMeanArea_in(:,idxActv);
Actv_Area_out = allMeanArea_out(:,idxActv);


% -------- CELL COUNTS --------

Ctrl_N_fov = allN_fov(:,idxCtrl);
Actv_N_in  = allN_in(:,idxActv);
Actv_N_out = allN_out(:,idxActv);


% -------- CELL DENSITY --------
%
% Per position and per frame, rho = N / A_eff (section 4.2b), in cells
% per mm^2. The ratio is computed position by position and only then
% averaged: fields differ in size and in the fraction of stripe they
% contain. The alternative 1 / <cell area> is not used because it
% ignores the extracellular gaps.

density_in  = allN_in  ./ validArea_in_um2.'  * 1e6;   % cells / mm^2
density_out = allN_out ./ validArea_out_um2.' * 1e6;   % cells / mm^2
density_fov = allN_fov ./ validArea_fov_um2.' * 1e6;   % cells / mm^2

Ctrl_Dens_fov = density_fov(:,idxCtrl);

Actv_Dens_in  = density_in(:,idxActv);
Actv_Dens_out = density_out(:,idxActv);


% -------- REGION USED FOR THE CONTROL CELL COUNT --------
%
% A density is intensive and comparable between regions of different
% size, but a raw count is not: the whole field holds about three times
% as many cells as the stripe simply because it is three times larger.
%
%   'stripe' -> Control counted inside the virtual stripe (comparable)
%   'fov'    -> Control counted over the whole field of view
%
% The density panel is the region-independent version of this
% measurement and is the one quoted in the text.

controlCountsRegion = 'stripe';

switch lower(controlCountsRegion)
    case 'stripe'
        Ctrl_N_plot = allN_in(:,idxCtrl);
    case 'fov'
        Ctrl_N_plot = Ctrl_N_fov;
    otherwise
        error('controlCountsRegion must be ''stripe'' or ''fov''.')
end

%% ============================================================
%  6) COMPUTE WEIGHTED MEAN, WEIGHTED STD AND WEIGHTED SEM
%     Averages across positions are weighted by the number of cells
%     inside the stripe (N_in). Per-cell values are already collapsed
%     to one mean per position in section 5, so std is the weighted
%     spread ACROSS POSITIONS and sem = std / sqrt(n positions), NOT
%     sqrt(n cells).
%% ============================================================

% -------- ASPECT RATIO --------
% Control curves are weighted by the cells of the whole field of view,
% ACTV curves by the cells inside the stripe.

[mean_Ctrl_AR, std_Ctrl_AR, sem_Ctrl_AR] = weightedRowStats(Ctrl_AR_fov, Ctrl_N_fov);
[mean_Actv_AR, std_Actv_AR, sem_Actv_AR] = weightedRowStats(Actv_AR_in,  Actv_N_in);

% -------- shape index (P) --------
% Dimensionless structural factor.
[mean_Ctrl_Pval, std_Ctrl_Pval, sem_Ctrl_Pval] = weightedRowStats(Ctrl_Pval_fov, Ctrl_N_fov);
[mean_Actv_Pval, std_Actv_Pval, sem_Actv_Pval] = weightedRowStats(Actv_Pval_in,  Actv_N_in);


% -------- AREA --------
% These values are in micrometers^2.

[mean_Ctrl_Area, std_Ctrl_Area, sem_Ctrl_Area] = weightedRowStats(Ctrl_Area_fov, Ctrl_N_fov);
[mean_Actv_Area, std_Actv_Area, sem_Actv_Area] = weightedRowStats(Actv_Area_in,  Actv_N_in);


% -------- CELL COUNTS --------
% Counts are NOT weighted (weighting a count by itself is meaningless).
% SEM = std / sqrt(number of positions contributing in that frame).

mean_Ctrl_N = mean(Ctrl_N_plot,2,'omitnan');
std_Ctrl_N  = std(Ctrl_N_plot,0,2,'omitnan');
nPos_Ctrl_N = sum(isfinite(Ctrl_N_plot),2);        % contributing positions
sem_Ctrl_N  = std_Ctrl_N ./ sqrt(nPos_Ctrl_N);

mean_Actv_N = mean(Actv_N_in,2,'omitnan');
std_Actv_N  = std(Actv_N_in,0,2,'omitnan');
nPos_Actv_N = sum(isfinite(Actv_N_in),2);          % contributing positions
sem_Actv_N  = std_Actv_N ./ sqrt(nPos_Actv_N);


% -------- DENSITY --------
% Already normalised by area, so averaged across positions WITHOUT
% cell-count weighting: that would bias the mean towards the densest
% fields, which is precisely the quantity being measured.

[mean_Ctrl_Dens, sem_Ctrl_Dens] = plainRowStats(Ctrl_Dens_fov);
[mean_Actv_Dens, sem_Actv_Dens] = plainRowStats(Actv_Dens_in);


%% ------------------------------------------------------------
%  6b) SAME ESTIMATORS FOR THE REGION OUTSIDE THE STRIPE
%      ACTV positions only, and only when showOutside is true. The
%      Control has no outside curve: its whole field of view is already
%      plotted in full. NaN placeholders keep the structs uniform.
%% ------------------------------------------------------------

[mean_Actv_AR_out, ~, sem_Actv_AR_out] = weightedRowStats(Actv_AR_out, Actv_N_out);

[mean_Actv_Pval_out, ~, sem_Actv_Pval_out] = weightedRowStats(Actv_Pval_out, Actv_N_out);

[mean_Actv_Area_out, ~, sem_Actv_Area_out] = weightedRowStats(Actv_Area_out, Actv_N_out);

[mean_Actv_N_out_m, sem_Actv_N_out_m] = plainRowStats(Actv_N_out);

[mean_Actv_Dens_out, sem_Actv_Dens_out] = plainRowStats(Actv_Dens_out);

% Placeholders for the Control (no outside region is drawn)
nanCol = nan(Tref,1);

mean_Ctrl_AR_out    = nanCol;   sem_Ctrl_AR_out    = nanCol;
mean_Ctrl_Pval_out  = nanCol;   sem_Ctrl_Pval_out  = nanCol;
mean_Ctrl_Area_out  = nanCol;   sem_Ctrl_Area_out  = nanCol;
mean_Ctrl_N_out_m   = nanCol;   sem_Ctrl_N_out_m   = nanCol;
mean_Ctrl_Dens_out  = nanCol;   sem_Ctrl_Dens_out  = nanCol;


%% ============================================================
%  7) COMMON Y LIMITS
%% ============================================================

% -------- ASPECT RATIO LIMITS --------

% The Control curves come from the whole-field averages, so they must
% enter the pool that fixes the y range.

if showOutside
    validAR_Y = [allMeanAR_in(:); allMeanAR_out(:); allMeanAR_fov(:)];
else
    validAR_Y = [allMeanAR_in(:); allMeanAR_fov(:)];
end

validAR_Y = validAR_Y(isfinite(validAR_Y));

if isempty(validAR_Y)

    commonYLim = [];

else

    yMin = min(validAR_Y);
    yMax = max(validAR_Y);
    yPad = 0.05 * (yMax - yMin);

    if yPad == 0
        yPad = 0.1;
    end

    commonYLim = [yMin - yPad, yMax + yPad];

end


% -------- AREA LIMITS --------
% Area is already in micrometers^2.

if showOutside
    validArea_Y = [allMeanArea_in(:); allMeanArea_out(:); allMeanArea_fov(:)];
else
    validArea_Y = [allMeanArea_in(:); allMeanArea_fov(:)];
end

validArea_Y = validArea_Y(isfinite(validArea_Y));

if isempty(validArea_Y)

    commonAreaYLim = [];

else

    areaYMin = min(validArea_Y);
    areaYMax = max(validArea_Y);
    areaYPad = 0.05 * (areaYMax - areaYMin);

    if areaYPad == 0
        areaYPad = 1;
    end

    commonAreaYLim = [areaYMin - areaYPad, areaYMax + areaYPad];

end

%% ============================================================
%  8) PLOT NUMBER OF CELLS
%      ACTV inside the stripe, Control over controlCountsRegion
%      (section 5, 'stripe' by default). A raw count scales with the
%      area of the region; section 10b is the region-independent version.
%% ============================================================

Ctrl_N.mean_in  = mean_Ctrl_N;       Ctrl_N.sem_in  = sem_Ctrl_N;
Ctrl_N.mean_out = mean_Ctrl_N_out_m; Ctrl_N.sem_out = sem_Ctrl_N_out_m;

Actv_N.mean_in  = mean_Actv_N;       Actv_N.sem_in  = sem_Actv_N;
Actv_N.mean_out = mean_Actv_N_out_m; Actv_N.sem_out = sem_Actv_N_out_m;

hFig = plotComparison(time, Ctrl_N, Actv_N, ...
    'Number of cells', 'Number of cells', showOutside, [], ...
    activationStartTime, activationEndTime, experimentEndTime, ...
    controlColor, actvColor, figSize_px, dockFigures, ...
    fontSizeAxes, fontSizeLegend);

lg = findobj(hFig, 'Type', 'legend');
lg.Position(2) = lg.Position(2) ;

saveCurrentFigure(hFig, resultsFolder, 'NumberCells');


%% ============================================================
%  9) PLOT AVERAGE CELL AREA
%      Cell-count weighted mean, +/- SEM band.
%% ============================================================

Ctrl_A.mean_in  = mean_Ctrl_Area;     Ctrl_A.sem_in  = sem_Ctrl_Area;
Ctrl_A.mean_out = mean_Ctrl_Area_out; Ctrl_A.sem_out = sem_Ctrl_Area_out;

Actv_A.mean_in  = mean_Actv_Area;     Actv_A.sem_in  = sem_Actv_Area;
Actv_A.mean_out = mean_Actv_Area_out; Actv_A.sem_out = sem_Actv_Area_out;

hFig = plotComparison(time, Ctrl_A, Actv_A, ...
    'Mean cell area ($\mu\mathrm{m}^2$)', ...
    'Average cell area: Control vs ACTV', showOutside, commonAreaYLim, ...
    activationStartTime, activationEndTime, experimentEndTime, ...
    controlColor, actvColor, figSize_px, dockFigures, ...
    fontSizeAxes, fontSizeLegend);

lg = findobj(hFig, 'Type', 'legend');
lg.Position(2) = lg.Position(2);

saveCurrentFigure(hFig, resultsFolder, 'Average_cell_area_Control_vs_ACTV');


%% ============================================================
%  10) PLOT AVERAGE SHAPE INDEX  P = perimeter / sqrt(area)
%      Cell-count weighted mean, +/- SEM band.
%% ============================================================

Ctrl_P.mean_in  = mean_Ctrl_Pval;     Ctrl_P.sem_in  = sem_Ctrl_Pval;
Ctrl_P.mean_out = mean_Ctrl_Pval_out; Ctrl_P.sem_out = sem_Ctrl_Pval_out;

Actv_P.mean_in  = mean_Actv_Pval;     Actv_P.sem_in  = sem_Actv_Pval;
Actv_P.mean_out = mean_Actv_Pval_out; Actv_P.sem_out = sem_Actv_Pval_out;

hFig = plotComparison(time, Ctrl_P, Actv_P, ...
    'Mean shape index', 'Average shape index: Control vs ACTV', ...
    showOutside, [], ...
    activationStartTime, activationEndTime, experimentEndTime, ...
    controlColor, actvColor, figSize_px, dockFigures, ...
    fontSizeAxes, fontSizeLegend);

lg = findobj(hFig, 'Type', 'legend');
lg.Position(2) = lg.Position(2);

saveCurrentFigure(hFig, resultsFolder, 'Average_Pval_Control_vs_ACTV');


%% ============================================================
%  10b) PLOT CELL DENSITY
%      rho = N / A_eff, computed per position and per frame and then
%      averaged across positions WITHOUT cell-count weighting.
%% ============================================================

Ctrl_D.mean_in  = mean_Ctrl_Dens;     Ctrl_D.sem_in  = sem_Ctrl_Dens;
Ctrl_D.mean_out = mean_Ctrl_Dens_out; Ctrl_D.sem_out = sem_Ctrl_Dens_out;

Actv_D.mean_in  = mean_Actv_Dens;     Actv_D.sem_in  = sem_Actv_Dens;
Actv_D.mean_out = mean_Actv_Dens_out; Actv_D.sem_out = sem_Actv_Dens_out;

hFig = plotComparison(time, Ctrl_D, Actv_D, ...
    'Cell density (cells$/$mm$^2$)', 'Cell density: Control vs ACTV', ...
    showOutside, [], ...
    activationStartTime, activationEndTime, experimentEndTime, ...
    controlColor, actvColor, figSize_px, dockFigures, ...
    fontSizeAxes, fontSizeLegend);

lg = findobj(hFig, 'Type', 'legend');
lg.Position(2) = lg.Position(2);

saveCurrentFigure(hFig, resultsFolder, 'Cell_density_Control_vs_ACTV');


%% ============================================================
%  11) shape index / AREA SPATIAL PROFILE ACROSS THE STRIPE
%      Uses the accumulators filled in the main loop (section 4).
%% ============================================================

%% ------------------------------------------------------------
%  11.1) Per-position profiles and group averages
%        Per-cell mean within a position, cell-count weighted across
%        positions (same criterion as section 6).
%% ------------------------------------------------------------

meanPval_prof = sumPval_prof ./ cnt_prof;     % 0/0 -> NaN
meanArea_prof = sumArea_prof ./ cnt_prof;

lowN = cnt_prof < minCellsPerBin;

meanPval_prof(lowN) = NaN;
meanArea_prof(lowN) = NaN;

Wprof = cnt_prof;
Wprof(lowN) = 0;

[Pvalprof_Ctrl, ~, Pvalsem_Ctrl] = weightedProfileStats(meanPval_prof(:,:,idxCtrl), Wprof(:,:,idxCtrl));
[Pvalprof_Actv, ~, Pvalsem_Actv] = weightedProfileStats(meanPval_prof(:,:,idxActv), Wprof(:,:,idxActv));

[Areaprof_Ctrl, ~, Areasem_Ctrl] = weightedProfileStats(meanArea_prof(:,:,idxCtrl), Wprof(:,:,idxCtrl));
[Areaprof_Actv, ~, Areasem_Actv] = weightedProfileStats(meanArea_prof(:,:,idxActv), Wprof(:,:,idxActv));


% -------- Temporal smoothing (display only) --------

if timeSmooth_frames > 1

    Pvalprof_Ctrl_s = movmean(Pvalprof_Ctrl, timeSmooth_frames, 2, 'omitnan');
    Pvalprof_Actv_s = movmean(Pvalprof_Actv, timeSmooth_frames, 2, 'omitnan');

    Pvalsem_Ctrl_s  = movmean(Pvalsem_Ctrl,  timeSmooth_frames, 2, 'omitnan');
    Pvalsem_Actv_s  = movmean(Pvalsem_Actv,  timeSmooth_frames, 2, 'omitnan');

    Areaprof_Ctrl_s = movmean(Areaprof_Ctrl, timeSmooth_frames, 2, 'omitnan');
    Areaprof_Actv_s = movmean(Areaprof_Actv, timeSmooth_frames, 2, 'omitnan');

else

    Pvalprof_Ctrl_s = Pvalprof_Ctrl;   Pvalprof_Actv_s = Pvalprof_Actv;
    Pvalsem_Ctrl_s  = Pvalsem_Ctrl;    Pvalsem_Actv_s  = Pvalsem_Actv;

    Areaprof_Ctrl_s = Areaprof_Ctrl;
    Areaprof_Actv_s = Areaprof_Actv;

end


%% ------------------------------------------------------------
%  11.2) MOVIE: shape index profile over time
%% ------------------------------------------------------------

if makeVideo

    allBandVals = [Pvalprof_Ctrl_s(:) + Pvalsem_Ctrl_s(:); ...
                   Pvalprof_Ctrl_s(:) - Pvalsem_Ctrl_s(:); ...
                   Pvalprof_Actv_s(:) + Pvalsem_Actv_s(:); ...
                   Pvalprof_Actv_s(:) - Pvalsem_Actv_s(:)];

    allBandVals = allBandVals(isfinite(allBandVals));

    if isempty(allBandVals)
        error('No valid profile data. Check binWidth_um / maxDist_um / minCellsPerBin.')
    end

    yLo = min(allBandVals);
    yHi = max(allBandVals);
    yPad = 0.05*(yHi - yLo);
    if yPad == 0
        yPad = 0.1;
    end
    ylProfile = [yLo - yPad, yHi + yPad];

    ylProfile = [3.8 4.1];

    videoBaseName = fullfile(resultsFolder, ...
        sprintf('Pval_profile_movie_%s', upper(profileAxis)));

    try
        vw = VideoWriter(videoBaseName, 'MPEG-4');
    catch
        vw = VideoWriter(videoBaseName, 'Motion JPEG AVI');
    end

    vw.FrameRate = videoFrameRate;
    open(vw);

    % Same size and fonts as the static figures. MPEG-4 needs EVEN
    % pixel dimensions, so the size is rounded up to even here.
    hVid = newFigure('', evenSize(figSize_px), false);
    set(hVid, 'Visible', 'off');

    axV = axes(hVid);
    hold(axV,'on')
    axV.FontSize = fontSizeAxes;

    if strcmpi(profileAxis,'x')
        patch(axV, ...
            [-1 1 1 -1]*stripeWidth_um/2, ...
            [ylProfile(1) ylProfile(1) ylProfile(2) ylProfile(2)], ...
            actvColor, ...
            'FaceAlpha',0.10, ...
            'EdgeColor',actvColor, ...
            'LineWidth',1.5, ...
            'HandleVisibility','off');
    end

    xline(axV, 0, 'k:', 'LineWidth', 1.2, 'HandleVisibility','off');

    hCtrlBand = fill(axV, NaN, NaN, controlColor, ...
        'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    hActvBand = fill(axV, NaN, NaN, actvColor, ...
        'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');

    hCtrlLine = plot(axV, binCenters_um, nan(nBins,1), ...
        'Color',controlColor,'LineWidth',3);
    hActvLine = plot(axV, binCenters_um, nan(nBins,1), ...
        'Color',actvColor,'LineWidth',3);

    if strcmpi(profileAxis,'x')
        xlabel(axV, 'Distance to stripe center, y ($\mu$m)')   % To match the orientation of the other experiments: rotation 90 -> x-> y
    else
        xlabel(axV, 'Distance to image center, x ($\mu$m)')
    end

    ylabel(axV, 'Mean shape index')

    xlim(axV, [-200 200])
    ylim(axV, ylProfile)

    lgV = legend(axV, [hCtrlLine hActvLine], {'Control','ACTV'}, ...
        'Location','northwest');
    lgV.FontSize = fontSizeLegend;

    grid(axV,'on')
    box(axV,'on')

    hTitle = title(axV, '');

    actvOffColor = [0.35 0.35 0.35];   % gray for ACTV OFF (use [0 0 0] for black)

    for t = 1:Tref
    
            % -------- Activation state and matching color --------
    
            if time(t) > activationStartTime && time(t) <= activationEndTime
                stateLabel = 'ACTV ON';
                actvNowColor = actvColor;        % blue while ON
            else
                stateLabel = 'ACTV OFF';
                actvNowColor = actvOffColor;     % gray/black while OFF
            end
    
            % -------- Update ACTV band + line with the current color --------
    
            updateBand(hCtrlBand, binCenters_um, Pvalprof_Ctrl_s(:,t), Pvalsem_Ctrl_s(:,t));
            updateBand(hActvBand, binCenters_um, Pvalprof_Actv_s(:,t), Pvalsem_Actv_s(:,t));
    
            set(hCtrlLine, 'YData', Pvalprof_Ctrl_s(:,t));
            set(hActvLine, 'YData', Pvalprof_Actv_s(:,t), 'Color', actvNowColor);
    
            set(hActvBand, 'FaceColor', actvNowColor);
    
            % -------- Title in the matching color --------
    
            set(hTitle, ...
                'String', sprintf('$t = %.2f$ h \\quad (%s)', time(t), stateLabel), ...
                'Color', actvNowColor);
    
            drawnow limitrate
            writeVideo(vw, getframe(hVid));
    
        end

    close(vw);
    close(hVid);

    fprintf('\nMovie saved: %s\n', videoBaseName);

end

%% ------------------------------------------------------------
%  11.2b) MOVIE: shape index profile RELATIVE TO A REFERENCE FRAME
%
%  Same profile as 11.2, but every position is referred to its own
%  value at the reference frame(s) BEFORE averaging:
%
%      relative :  100 * ( p(y,t) - p_ref(y) ) / p_ref(y)     [%]
%      absolute :          p(y,t) - p_ref(y)
%
%  Normalising per position removes the field-to-field offset in the
%  absolute shape index, which otherwise hides the response. The
%  reference is per position and per bin, so a bin with no valid
%  reference propagates NaN to its whole time series.
%% ------------------------------------------------------------

% -------- PARAMETERS --------

makeVideoRel = true;

% refFrames = (activationStartFrame - 9)  : activationStartFrame;   % ~30 min
% refFrames = (activationStartFrame - 4)  : activationStartFrame;   % ~15 min
refFrames = (activationStartFrame - 2)  : activationStartFrame;   % ~9 min


relMode      = 'relative';             % 'relative' (%) or 'absolute'

xlimRel      = [-200 200];               % same range as the movie of 11.2
ylimRel      = [-4 2.5];                     % [] = automatic, or e.g. [-2 4]


if makeVideoRel

    % -------- Reference profile, per position and per bin --------

    refFrames = refFrames(refFrames >= 1 & refFrames <= Tref);

    if isempty(refFrames)
        error('refFrames is empty or out of range (1..%d).', Tref)
    end

    Pref = mean(meanPval_prof(:,refFrames,:), 2, 'omitnan');   % [nBins x 1 x nFiles]

    % -------- Difference with respect to the reference --------

    switch lower(relMode)

        case 'relative'
            Pref(Pref == 0) = NaN;                       % guard against 0/0
            Prel_pos = 100 * (meanPval_prof - Pref) ./ Pref;
            relLabel = 'Shape index change (\%)';

        case 'absolute'
            Prel_pos = meanPval_prof - Pref;
            relLabel = '$\Delta$ shape index';

        otherwise
            error('relMode must be ''relative'' or ''absolute''.')

    end

    % A bin without a valid reference cannot be normalised
    Prel_pos(~isfinite(Prel_pos)) = NaN;

    % -------- Group averages, same weighting as section 11.1 --------

    [Prel_Ctrl, ~, Prelsem_Ctrl] = weightedProfileStats(Prel_pos(:,:,idxCtrl), Wprof(:,:,idxCtrl));
    [Prel_Actv, ~, Prelsem_Actv] = weightedProfileStats(Prel_pos(:,:,idxActv), Wprof(:,:,idxActv));

    % -------- Temporal smoothing (display only) --------

    if timeSmooth_frames > 1
        Prel_Ctrl_s    = movmean(Prel_Ctrl,    timeSmooth_frames, 2, 'omitnan');
        Prel_Actv_s    = movmean(Prel_Actv,    timeSmooth_frames, 2, 'omitnan');
        Prelsem_Ctrl_s = movmean(Prelsem_Ctrl, timeSmooth_frames, 2, 'omitnan');
        Prelsem_Actv_s = movmean(Prelsem_Actv, timeSmooth_frames, 2, 'omitnan');
    else
        Prel_Ctrl_s    = Prel_Ctrl;      Prel_Actv_s    = Prel_Actv;
        Prelsem_Ctrl_s = Prelsem_Ctrl;   Prelsem_Actv_s = Prelsem_Actv;
    end

    % -------- Y limits --------

    if isempty(ylimRel)

        allRelVals = [Prel_Ctrl_s(:) + Prelsem_Ctrl_s(:); ...
                      Prel_Ctrl_s(:) - Prelsem_Ctrl_s(:); ...
                      Prel_Actv_s(:) + Prelsem_Actv_s(:); ...
                      Prel_Actv_s(:) - Prelsem_Actv_s(:)];

        allRelVals = allRelVals(isfinite(allRelVals));

        if isempty(allRelVals)
            error(['No valid relative profile data. Try widening refFrames ' ...
                   'or lowering minCellsPerBin.'])
        end

        yLoR = min(allRelVals);
        yHiR = max(allRelVals);
        yPadR = 0.05*(yHiR - yLoR);

        if yPadR == 0
            yPadR = 0.1;
        end

        ylProfileRel = [yLoR - yPadR, yHiR + yPadR];

    else
        ylProfileRel = ylimRel;
    end

    % -------- Video writer --------

    videoBaseName = fullfile(resultsFolder, ...
        sprintf('Pval_profile_relative_movie_%s', upper(profileAxis)));

    try
        vw = VideoWriter(videoBaseName, 'MPEG-4');
    catch
        vw = VideoWriter(videoBaseName, 'Motion JPEG AVI');
    end

    vw.FrameRate = videoFrameRate;
    open(vw);

    % -------- Figure (same size and fonts as the static figures) --------

    hVid = newFigure('', evenSize(figSize_px), false);
    set(hVid, 'Visible', 'off');

    axV = axes(hVid);
    hold(axV,'on')
    axV.FontSize = fontSizeAxes;

    if strcmpi(profileAxis,'x')
        patch(axV, ...
            [-1 1 1 -1]*stripeWidth_um/2, ...
            [ylProfileRel(1) ylProfileRel(1) ylProfileRel(2) ylProfileRel(2)], ...
            actvColor, ...
            'FaceAlpha',0.10, ...
            'EdgeColor',actvColor, ...
            'LineWidth',1.5, ...
            'HandleVisibility','off');
    end

    xline(axV, 0, 'k:', 'LineWidth', 1.2, 'HandleVisibility','off');
    yline(axV, 0, 'k-', 'LineWidth', 1.2, 'HandleVisibility','off');   % reference level

    hCtrlBand = fill(axV, NaN, NaN, controlColor, ...
        'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    hActvBand = fill(axV, NaN, NaN, actvColor, ...
        'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');

    hCtrlLine = plot(axV, binCenters_um, nan(nBins,1), ...
        'Color',controlColor,'LineWidth',3);
    hActvLine = plot(axV, binCenters_um, nan(nBins,1), ...
        'Color',actvColor,'LineWidth',3);

    if strcmpi(profileAxis,'x')
        xlabel(axV, 'Distance to stripe center, y ($\mu$m)')
    else
        xlabel(axV, 'Distance to image center, x ($\mu$m)')
    end

    ylabel(axV, relLabel)

    xlim(axV, xlimRel)
    ylim(axV, ylProfileRel)

    lgV = legend(axV, [hCtrlLine hActvLine], {'Control','ACTV'}, ...
        'Location','northwest');
    lgV.FontSize = fontSizeLegend;

    grid(axV,'on')
    box(axV,'on')

    hTitle = title(axV, '');

    actvOffColor = [0.35 0.35 0.35];

    % -------- Frame loop --------

    for t = 1:Tref

        if time(t) > activationStartTime && time(t) <= activationEndTime
            stateLabel   = 'ACTV ON';
            actvNowColor = actvColor;
        else
            stateLabel   = 'ACTV OFF';
            actvNowColor = actvOffColor;
        end

        updateBand(hCtrlBand, binCenters_um, Prel_Ctrl_s(:,t), Prelsem_Ctrl_s(:,t));
        updateBand(hActvBand, binCenters_um, Prel_Actv_s(:,t), Prelsem_Actv_s(:,t));

        set(hCtrlLine, 'YData', Prel_Ctrl_s(:,t));
        set(hActvLine, 'YData', Prel_Actv_s(:,t), 'Color', actvNowColor);

        set(hActvBand, 'FaceColor', actvNowColor);

        set(hTitle, ...
            'String', sprintf('$t = %.2f$ h \\quad (%s)', time(t), stateLabel), ...
            'Color', actvNowColor);

        drawnow limitrate
        writeVideo(vw, getframe(hVid));

    end

    close(vw);
    close(hVid);

    fprintf('\nRelative profile movie saved: %s\n', videoBaseName);

end

%% ------------------------------------------------------------
%  11.2c) STATIC PROFILES AT SELECTED TIME POINTS
%
%  Two figures, one per condition, with the ABSOLUTE shape index
%  profile averaged over a few short time windows. Colour encodes
%  time, light to dark within one hue family. Static counterpart of
%  the movie of 11.2, with the conditions kept apart to avoid eight
%  overlapping curves in one panel.
%
%  Ramps are sampled from perceptually ordered colormaps rather than
%  interpolated towards white, and each time point is averaged over a
%  WINDOW of frames, since a single frame is too noisy at this bin
%  size.
%% ------------------------------------------------------------

% -------- PARAMETERS --------

showSnapBands = false;

makeStaticProfiles = true;

snapWindow_min = 30;        % averaging window around each time point (min)

% Time points (h). Edit freely: the code adapts to any number of them.
snapTimes_h = [ 1.0, ...    % basal, before activation
                2.5, ...    % onset, just after ACTV ON
                4.0, ...    % during activation, steady state
               15.0 ];      % end of the experiment, after relaxation

snapLabels = { 'Basal (1 h)', ...
               'Onset (2.5 h)', ...
               'ACTV (4.0 h)', ...
               'Final (15 h)' };

% Colour ramps. Each row of the colormap is sampled between rampRange
% fractions, from light (early times) to dark (late times).
actvColormap = 'winter';    % blues/greens   -> ACTV
ctrlColormap = 'autumn';    % reds/magentas  -> Control

rampRange = [0.15 0.85];    % fraction of the colormap actually used
rampDarken = 0.85;          % <1 darkens the whole ramp slightly

xlimSnap      = [-200 200];
ylimSnap      = [];         % [] = automatic over the shown bins


if makeStaticProfiles

    nSnap = numel(snapTimes_h);

    if numel(snapLabels) ~= nSnap
        error('snapTimes_h and snapLabels must have the same length.')
    end

    snapHalfSpan = round( (snapWindow_min/2) / frameDuration_min );

    % -------- Frame windows around each time point --------

    snapIdx = cell(nSnap,1);

    for k = 1:nSnap

        [~, cFrame] = min(abs(time - snapTimes_h(k)));

        idxK = (cFrame - snapHalfSpan) : (cFrame + snapHalfSpan);
        idxK = idxK(idxK >= 1 & idxK <= Tref);

        if isempty(idxK)
            error('Time point %.2f h falls outside the recording.', snapTimes_h(k))
        end

        snapIdx{k} = idxK;

    end

    % -------- Colour ramps sampled from the colormaps --------

    nCm = 256;

    cmActv = feval(actvColormap, nCm);
    cmCtrl = feval(ctrlColormap, nCm);

% Row indices from the light end to the dark end of each colormap.
% 'winter' and 'autumn' both run light -> dark in this direction.
    rampIdx = round(linspace(rampRange(1)*nCm, rampRange(2)*nCm, nSnap));
    rampIdx = max(1, min(nCm, rampIdx));

    actvRamp = cmActv(rampIdx,:) * rampDarken;
    ctrlRamp = cmCtrl(rampIdx,:) * rampDarken;

    % -------- Common y limits for BOTH figures --------
    % Fixed jointly so the two panels are directly comparable.

    shownBinsSnap = binCenters_um >= xlimSnap(1) & binCenters_um <= xlimSnap(2);

    if isempty(ylimSnap)

        pool = [];

        for k = 1:nSnap
            for src = 1:2
                if src == 1
                    M = Pvalprof_Ctrl;  S = Pvalsem_Ctrl;
                else
                    M = Pvalprof_Actv;  S = Pvalsem_Actv;
                end
                mk = mean(M(shownBinsSnap, snapIdx{k}), 2, 'omitnan');
                sk = mean(S(shownBinsSnap, snapIdx{k}), 2, 'omitnan');
                pool = [pool; mk + sk; mk - sk];   %#ok<AGROW>
            end
        end

        pool = pool(isfinite(pool));

        if isempty(pool)
            error('No valid profile data at the selected time points.')
        end

        yLoS = min(pool);
        yHiS = max(pool);
        yPadS = 0.05*(yHiS - yLoS);

        if yPadS == 0
            yPadS = 0.05;
        end

        ylProfileSnap = [yLoS - yPadS, yHiS + yPadS];

    else
        ylProfileSnap = ylimSnap;
    end

    % -------- One figure per condition --------

    for src = 1:2

        if src == 1
            Mprof = Pvalprof_Ctrl;   Sprof = Pvalsem_Ctrl;
            ramp  = ctrlRamp;
            condName = 'Control';
            baseName = 'Pval_profile_snapshots_Control';
        else
            Mprof = Pvalprof_Actv;   Sprof = Pvalsem_Actv;
            ramp  = actvRamp;
            condName = 'ACTV';
            baseName = 'Pval_profile_snapshots_ACTV';
        end

        hFig = newFigure(['Shape index profiles - ' condName], ...
                         figSize_px, dockFigures);

        ax = axes(hFig);
        hold(ax, 'on')
        ax.FontSize = fontSizeAxes;

        % Activation stripe footprint
        if strcmpi(profileAxis,'x')
            patch(ax, ...
                [-1 1 1 -1]*stripeWidth_um/2, ...
                [ylProfileSnap(1) ylProfileSnap(1) ylProfileSnap(2) ylProfileSnap(2)], ...
                actvColor, ...
                'FaceAlpha',0.10, ...
                'EdgeColor',actvColor, ...
                'LineWidth',1.5, ...
                'HandleVisibility','off');
        end

        xline(ax, 0, 'k:', 'LineWidth', 1.2, 'HandleVisibility','off');

        hSnap = gobjects(nSnap,1);

        for k = 1:nSnap

            mk = mean(Mprof(:, snapIdx{k}), 2, 'omitnan');
            sk = mean(Sprof(:, snapIdx{k}), 2, 'omitnan');

            if showSnapBands
                fillBand(ax, binCenters_um, mk, sk, ramp(k,:));
            end

   
            hSnap(k) = plot(ax, binCenters_um, mk, '-', ...
                'Color', ramp(k,:), 'LineWidth', 3);

        end

        if strcmpi(profileAxis,'x')
            xlabel(ax, 'Distance to stripe center, y ($\mu$m)')
        else
            xlabel(ax, 'Distance to image center, x ($\mu$m)')
        end

        ylabel(ax, 'Mean shape index')
        title(ax, condName)

        xlim(ax, xlimSnap)
        ylim(ax, ylProfileSnap)

        lg = legend(ax, hSnap, snapLabels, 'Location', 'northwest');
        lg.FontSize = fontSizeLegend;

        grid(ax, 'on')
        box(ax, 'on')
        hold(ax, 'off')

        drawnow

        saveCurrentFigure(hFig, resultsFolder, baseName);

    end

    fprintf('\nStatic profile figures saved (Control and ACTV).\n');

end


%% ============================================================
%  12) PER-CELL shape index MAP MOVIE
%      Each cell is colored by its shape index P = perimeter/sqrt(area),
%      complementary to the binned spatial profile of section 11.
%% ============================================================

% -------- PARAMETERS --------

mapPositions   = [8];        % position(s) to render (one movie each)
mapColormap    = 'turbo';    % 'turbo' / 'parula' / 'jet'
climPrctile    = [2 98];     % robust color limits (percentiles of P)
showBoundaries = true;       % draw white cell outlines
mapFrameRate   = 20;

actvOffColor   = [0.35 0.35 0.35];   % gray for ACTV OFF title/stripe


for e = 1:numel(mapPositions)

    posMap = mapPositions(e);

    fprintf('P-map movie: processing position %d...\n', posMap);

    % -------- Load label matrix for this position --------

    data = load(fullfile(dataFolder, fileNames(posMap)));

    if isfield(data,'LabelMatrix')
        LabelMatrix = data.LabelMatrix;
    else
        fn = fieldnames(data);
        LabelMatrix = data.(fn{1});
    end

    Tmap        = size(LabelMatrix,3);
    imageHeight = size(LabelMatrix,1);
    imageWidth  = size(LabelMatrix,2);

    % -------- Stripe center / limits for this position --------

    Region = MBI.Regions([MBI.Regions.InPosition] == posMap);

    if isempty(Region)
        error('No MBI.Regions entry found for position %d', posMap)
    else
        Region = Region(1);
    end

    stripeCenterX_map = imageWidth/2 + Region.RelXinPosition;
    stripeXMin_map = max(1,          stripeCenterX_map - stripeHalfWidth_px);
    stripeXMax_map = min(imageWidth, stripeCenterX_map + stripeHalfWidth_px);


    %% --------------------------------------------------------
    %  12.1) PASS 1: per-cell P for every frame + global color limits
    %% --------------------------------------------------------

    Pvec_all = cell(Tmap,1);
    allP     = [];

    for t = 1:Tmap

        L = LabelMatrix(:,:,t);

        stats = regionprops(L, 'Area', 'Perimeter');

        if isempty(stats)
            Pvec_all{t} = [];
            continue
        end

        areas_px2     = [stats.Area]';
        perimeters_px = [stats.Perimeter]';

        Pvec = perimeters_px ./ sqrt(areas_px2);
        Pvec(areas_px2 <= 0 | perimeters_px <= 0 | ~isfinite(Pvec)) = NaN;

        Pvec_all{t} = Pvec;
        allP = [allP; Pvec(isfinite(Pvec))]; %#ok<AGROW>

    end

    if isempty(allP)
        warning('Position %d has no valid cells; skipping movie.', posMap);
        continue
    end

    cLo = prctile(allP, climPrctile(1));
    cHi = prctile(allP, climPrctile(2));

    if cLo == cHi
        cHi = cLo + 1;
    end


    %% --------------------------------------------------------
    %  12.2) PASS 2: render frames and write the movie
    %% --------------------------------------------------------

    videoBaseName = fullfile(resultsFolder, ...
        sprintf('Pval_map_movie_Pos%02d', posMap));

    try
        vw = VideoWriter(videoBaseName, 'MPEG-4');
    catch
        vw = VideoWriter(videoBaseName, 'Motion JPEG AVI');
    end

    vw.FrameRate = mapFrameRate;
    open(vw);

% Taller than the line figures, same width and same fonts.
    hVid = newFigure('', evenSize(figSizeMap_px), false);
    set(hVid, 'Visible', 'off');

    axV = axes(hVid);
    set(axV, 'Color', 'k');          % black background behind cells
    hold(axV, 'on')
    axV.FontSize = fontSizeAxes;

    % Image object (created once, updated per frame)
    hImg = imagesc(axV, nan(imageHeight, imageWidth));
    set(axV, 'YDir', 'reverse');     % image convention
    axis(axV, 'image')
    xlim(axV, [0.5 imageWidth+0.5])
    ylim(axV, [0.5 imageHeight+0.5])

    colormap(axV, mapColormap);
    try
        clim(axV, [cLo cHi]);
    catch
        caxis(axV, [cLo cHi]);       %#ok<CAXIS>  % older MATLAB
    end

    cb = colorbar(axV);
    cb.Label.String = 'shape index $P = \mathrm{perimeter}/\sqrt{\mathrm{area}}$';
    cb.Label.Interpreter = 'latex';
    cb.Color = 'k';

    % Optional boundary overlay (created once, updated per frame)
    if showBoundaries
        hBnd = plot(axV, NaN, NaN, '.', 'Color', [1 1 1 0.5], 'MarkerSize', 1);
    end

    % Vertical activation stripe outline (fixed position)
    hStripe = plot(axV, ...
        [stripeXMin_map stripeXMax_map stripeXMax_map stripeXMin_map stripeXMin_map], ...
        [0.5 0.5 imageHeight+0.5 imageHeight+0.5 0.5], ...
        '-', 'LineWidth', 3, 'Color', actvColor);

    xticks(axV, []); yticks(axV, []);
    box(axV, 'on')

    hTitle = title(axV, '');

    for t = 1:Tmap

        L    = LabelMatrix(:,:,t);
        Pvec = Pvec_all{t};

        % -------- Build the per-pixel P image --------

        Pimg = nan(imageHeight, imageWidth);
        fg   = L > 0;

        if ~isempty(Pvec)
            % Guard: label indices must not exceed the Pvec length
            valPix = fg & (L <= numel(Pvec));
            Pimg(valPix) = Pvec(L(valPix));
        end

        set(hImg, 'CData', Pimg, 'AlphaData', ~isnan(Pimg));

        % -------- Update boundaries --------

        if showBoundaries
            Bmask = boundarymask(L);
            [yb, xb] = find(Bmask);
            set(hBnd, 'XData', xb, 'YData', yb);
        end

        % -------- Activation state -> stripe + title color --------

        if time(t) > activationStartTime && time(t) <= activationEndTime
            stateLabel   = 'ACTV ON';
            stateColor   = actvColor;
        else
            stateLabel   = 'ACTV OFF';
            stateColor   = actvOffColor;
        end

        set(hStripe, 'Color', stateColor);

        set(hTitle, ...
            'String', sprintf('Pos %02d \\quad $t = %.2f$ h \\quad (%s)', ...
                              posMap, time(t), stateLabel), ...
            'Color', stateColor);

        drawnow limitrate
        writeVideo(vw, getframe(hVid));

    end

    close(vw);
    close(hVid);

    fprintf('P-map movie saved: %s\n', videoBaseName);

end


%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================


function hFig = newFigure(figName, sizePx, dockFigures)
% NEWFIGURE  Create a figure with a controlled, reproducible size.
%
%   Docked figures cannot have their size set and exportgraphics
%   writes the ON-SCREEN size, so every undocked figure created here
%   shares the same pixel size. MATLAB clamps Position to the display
%   and a warning is issued if that happens.

if nargin < 3 || isempty(dockFigures), dockFigures = false; end

hFig = figure('Color','w');

if ~isempty(figName)
    set(hFig, 'Name', char(figName), 'NumberTitle', 'off');
end

if dockFigures
    set(hFig, 'WindowStyle', 'docked');
    return                       % size is the dock's business now
end

set(hFig, 'WindowStyle', 'normal', ...
          'Units', 'pixels', ...
          'Position', [100 100 sizePx(1) sizePx(2)]);

actual = get(hFig, 'Position');

if any(abs(actual(3:4) - sizePx(:)') > 1)
    warning(['Figure clamped to %d x %d px by the display ' ...
             '(requested %d x %d). Exports will not match.'], ...
            round(actual(3)), round(actual(4)), sizePx(1), sizePx(2));
end

end


function sz = evenSize(sizePx)
% EVENSIZE  Round a figure size up to even pixels.
%   The MPEG-4 encoder rejects odd frame dimensions and getframe
%   returns the figure size, so it is forced even here.

sz = 2 * ceil(sizePx(:)' / 2);

end


function saveCurrentFigure(hFig, resultsFolder, baseName)

% Make sure the output folder exists.
if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

% Output path. Only the PNG is written: no .fig files are saved.
pngPath = fullfile(resultsFolder, [baseName '.png']);

% Save high-resolution PNG.
try
    exportgraphics(hFig, pngPath, 'Resolution', 300);
catch
    % Fallback for older MATLAB versions.
    saveas(hFig, pngPath);
end

end


function [m, s, sem] = weightedRowStats(X, W)
% WEIGHTEDROWSTATS  Per-row (per-time) weighted mean, std and SEM.
%
%   X, W are [Tref x nPos]: one column per position, one row per
%   frame. For every row the weighted mean, unbiased weighted std and
%   SEM across positions are computed, using W as weights.
%
%   - NaN entries in X (or non-positive weights) are ignored.
%   - var = sum(w (x-m)^2) / ( sum(w) - sum(w^2)/sum(w) )
%   - sem = std / sqrt(nEff), nEff = contributing POSITIONS, not
%     cells. Rows with a single position return NaN std and sem.

valid = isfinite(X) & isfinite(W) & (W > 0);

Xv = X;  Xv(~valid) = 0;
Wv = W;  Wv(~valid) = 0;

sumW  = sum(Wv, 2);
sumW2 = sum(Wv.^2, 2);

% Weighted mean
m = sum(Wv .* Xv, 2) ./ sumW;

% Weighted (unbiased, reliability weights) variance and std
d2 = (Xv - m).^2;
d2(~valid) = 0;

denom = sumW - sumW2 ./ sumW;
v = sum(Wv .* d2, 2) ./ denom;
s = sqrt(v);

% SEM: std divided by sqrt of number of contributing POSITIONS
nEff = sum(valid, 2);
sem  = s ./ sqrt(nEff);

% Degenerate rows
m(sumW == 0)   = NaN;   % no cells anywhere this frame
s(sumW == 0)   = NaN;
s(denom <= 0)  = NaN;   % only one contributing position
sem(sumW == 0) = NaN;
sem(denom <= 0)= NaN;
end


function addActivationWindow(activationStartTime, activationEndTime, ax, shadeColor, showLabels)
% ADDACTIVATIONWINDOW  Shade the activation window and mark its boundaries.
%
%   Draws a semi-transparent band between activationStartTime and
%   activationEndTime, plus dashed vertical lines at both edges.

if nargin < 3 || isempty(ax),         ax = gca;                 end
if nargin < 4 || isempty(shadeColor), shadeColor = [0.2 0.4 1]; end
if nargin < 5 || isempty(showLabels), showLabels = false;       end

% -------- Shaded activation window --------
try
    % R2023a and newer: spans the full y range automatically, stays
    % behind the data and follows any later change of the y limits.
    hReg = xregion(ax, activationStartTime, activationEndTime, ...
        'FaceColor', shadeColor, ...
        'FaceAlpha', 0.12, ...
        'EdgeColor', 'none');
    set(hReg, 'HandleVisibility', 'off');
catch
    % Fallback for older MATLAB releases.
    yl = ylim(ax);
    hReg = patch(ax, ...
        [activationStartTime activationEndTime activationEndTime activationStartTime], ...
        [yl(1) yl(1) yl(2) yl(2)], ...
        shadeColor, ...
        'FaceAlpha', 0.12, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    uistack(hReg, 'bottom');
    ylim(ax, yl);   % freeze limits so the patch cannot drive autoscaling
end

% -------- Dashed boundaries --------
if showLabels
    xline(ax, activationStartTime, 'k--', 'ACTV ON', ...
        'LineWidth', 1.3, 'HandleVisibility', 'off', ...
        'LabelVerticalAlignment', 'bottom', ...
        'LabelHorizontalAlignment', 'left');
    xline(ax, activationEndTime, 'k--', 'ACTV OFF', ...
        'LineWidth', 1.3, 'HandleVisibility', 'off', ...
        'LabelVerticalAlignment', 'bottom', ...
        'LabelHorizontalAlignment', 'left');
else
    xline(ax, activationStartTime, 'k--', 'LineWidth', 1.3, 'HandleVisibility','off');
    xline(ax, activationEndTime,   'k--', 'LineWidth', 1.3, 'HandleVisibility','off');
end

end


%% ============================================================
%  ADDITIONAL LOCAL FUNCTIONS
%% ============================================================

function [m, s, sem] = weightedProfileStats(X, W)
% WEIGHTEDPROFILESTATS  Weighted mean/std/SEM across positions (dim 3).
%   X, W are [nBins x Tref x nPos]. For each (bin, frame), computes the
%   cell-count weighted mean, unbiased weighted std and SEM across the
%   contributing positions. Same estimator as weightedRowStats.

valid = isfinite(X) & isfinite(W) & (W > 0);

Xv = X;  Xv(~valid) = 0;
Wv = W;  Wv(~valid) = 0;

sumW  = sum(Wv, 3);
sumW2 = sum(Wv.^2, 3);

m = sum(Wv .* Xv, 3) ./ sumW;

d2 = (Xv - m).^2;
d2(~valid) = 0;

denom = sumW - sumW2 ./ sumW;
v = sum(Wv .* d2, 3) ./ denom;
s = sqrt(v);

nEff = sum(valid, 3);
sem  = s ./ sqrt(nEff);

m(sumW == 0)    = NaN;
s(sumW == 0)    = NaN;
s(denom <= 0)   = NaN;
sem(sumW == 0)  = NaN;
sem(denom <= 0) = NaN;
end


function updateBand(hFill, x, mu, se)
% Update an existing fill object with a mean +/- SEM shaded band.
x = x(:).';  mu = mu(:).';  se = se(:).';
ok = isfinite(mu) & isfinite(se);
if ~any(ok)
    set(hFill, 'XData', NaN, 'YData', NaN);
    return
end
xk = x(ok);  up = mu(ok) + se(ok);  lo = mu(ok) - se(ok);
set(hFill, 'XData', [xk, fliplr(xk)], 'YData', [up, fliplr(lo)]);
end


function fillBand(ax, x, mu, se, col)
% Draw a static mean +/- SEM shaded band on axes ax.
x = x(:).';  mu = mu(:).';  se = se(:).';
ok = isfinite(mu) & isfinite(se);
if ~any(ok)
    return
end
xk = x(ok);  up = mu(ok) + se(ok);  lo = mu(ok) - se(ok);
fill(ax, [xk, fliplr(xk)], [up, fliplr(lo)], col, ...
    'FaceAlpha',0.2, 'EdgeColor','none', 'HandleVisibility','off');
end


function [m, sem] = plainRowStats(X)
% PLAINROWSTATS  Per-row (per-time) UNWEIGHTED mean and SEM across positions.
%
%   X is [Tref x nPos]. Returns the plain mean across positions and
%   SEM = std / sqrt(nPos) for every row. Used for the quantities
%   that must NOT be cell-count weighted: the cell counts and the
%   density.

m    = mean(X, 2, 'omitnan');
sd   = std(X, 0, 2, 'omitnan');
nPos = sum(isfinite(X), 2);

sem  = sd ./ sqrt(nPos);

m(nPos == 0)   = NaN;
sem(nPos <= 1) = NaN;   % spread cannot be estimated from one position

end


function hFig = plotComparison(time, C, A, yLab, figName, showOutside, yLimits, ...
        activationStartTime, activationEndTime, experimentEndTime, ...
        controlColor, actvColor, figSize_px, dockFigures, ...
        fontSizeAxes, fontSizeLegend)
% PLOTCOMPARISON  Control vs ACTV time course, inside and outside the stripe.
%
%   C and A are structs (Control and ACTV) with the fields
%       .mean_in  .sem_in  .mean_out  .sem_out
%   all column vectors of length numel(time).
%
%   For ACTV, .mean_in / .mean_out are the cells inside and outside
%   the stripe; the outside curve is drawn only when showOutside is
%   true. For the Control, .mean_in holds the whole-field average and
%   .mean_out is unused (NaN), so its curve is labelled "Control (FOV)".
%
%   Every curve carries a mean +/- SEM band. yLimits may be empty.

hFig = newFigure(figName, figSize_px, dockFigures);
ax = axes(hFig);
hold(ax, 'on')
ax.FontSize = fontSizeAxes;

% -------- Inside the stripe: shaded bands, then solid lines --------

fillBand(ax, time, C.mean_in, C.sem_in, controlColor);
fillBand(ax, time, A.mean_in, A.sem_in, actvColor);

hCin = plot(ax, time, C.mean_in, '-', 'Color', controlColor, 'LineWidth', 3);
hAin = plot(ax, time, A.mean_in, '-', 'Color', actvColor,    'LineWidth', 3);

hLines  = [hCin hAin];

if showOutside
    hLabels = {'Control (FOV)','ACTV (inside)'};
else
    hLabels = {'Control (FOV)','ACTV'};
end

% -------- Outside the stripe: same bands, dashed lines --------

% -------- Outside the stripe: same bands, lighter solid lines --------
%
% Hue encodes the condition and lightness the region, so the two stay
% visually independent. Only ACTV has an outside curve: the Control
% field of view is already plotted in full.

if showOutside

    outsideShade = 0.55;   % 1 = same color, 0 = black

    actvColorOut = actvColor * outsideShade;

    fillBand(ax, time, A.mean_out, A.sem_out, actvColorOut);

    hAout = plot(ax, time, A.mean_out, '-', ...
        'Color', actvColorOut, 'LineWidth', 2.5);

    hLines  = [hCin hAin hAout];
    hLabels = {'Control (FOV)','ACTV (inside)','ACTV (outside)'};

end

xlabel(ax, 'Time (h)')
ylabel(ax, yLab)

addActivationWindow(activationStartTime, activationEndTime, ax)

lg = legend(ax, hLines, hLabels, 'Location', 'best');
lg.FontSize = fontSizeLegend;

if ~isempty(yLimits)
    ylim(ax, yLimits)
end

xlim(ax, [0 experimentEndTime])

grid(ax, 'on')
box(ax, 'on')
hold(ax, 'off')

drawnow

end