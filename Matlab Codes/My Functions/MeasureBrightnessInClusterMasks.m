function [meanBrightness, maskAreaPixels] = ...
    MeasureBrightnessInClusterMasks( ...
    imageFolder, clusterFiles, GoodPositions, ...
    maskFile, TFM, MBI, outputFolder, showFigure, saveFigure, ...
    pxSize_um, barLength_um, barOnAllPanels)

% -------- INPUT CHECK --------

if nargin < 12 || isempty(barOnAllPanels)
    barOnAllPanels = true;      % false -> solo en el ultimo panel
end

if nargin < 11 || isempty(barLength_um)
    barLength_um = 100;
end

if nargin < 10
    pxSize_um = [];             % vacio -> no se dibuja barra de escala
end

if nargin < 9
    saveFigure = false;
end

if nargin < 8
    showFigure = true;
end

if nargin < 7 || isempty(outputFolder)
    outputFolder = "Results";
end

% -------- OUTPUT FOLDER --------

if ~exist(outputFolder, "dir")
    mkdir(outputFolder)
end

% -------- LOAD MASKS --------

load(maskFile, "ClusterMasks");

% -------- OUTPUT VARIABLES --------

meanBrightness = nan(max(GoodPositions),1);
maskAreaPixels = nan(max(GoodPositions),1);

% -------- FIGURE SETUP --------

makeFigure = showFigure || saveFigure;

if makeFigure

    nImages = numel(GoodPositions);

    nCols = nImages;
    nRows = 1;

    if showFigure
        fig = figure("Color", "w", "Position", [100, 100, 300*nImages, 300]);
    else
        fig = figure("Color", "w", "Position", [100, 100, 300*nImages, 300], "Visible", "off");
    end

    tiledlayout(nRows, nCols, ...
        "Padding", "compact", ...
        "TileSpacing", "compact");

end

% -------- LOOP OVER POSITIONS --------

for k = 1:numel(GoodPositions)

    p = GoodPositions(k);

    filepath = fullfile( ...
        imageFolder, ...
        clusterFiles(p));

    % --- Original fluorescence image ---

    I_raw = imread(filepath, 1);

    % --- Registration shift ---

    dx = round(MBI.Registration.Shift(p,1,1));
    dy = round(MBI.Registration.Shift(p,1,2));

    I_shift = circshift(I_raw, [dy dx]);

    % --- Crop used in TFM ---

    Crop = TFM{p}.Settings;

    I_crop = I_shift( ...
        Crop.ROI1, ...
        Crop.ROI2);

    % --- Resize MASK to image dimensions (imagen nunca se toca) ---

    MaskCluster = ClusterMasks{p};

    MaskResized = imresize(MaskCluster, size(I_crop), "nearest");

    % --- Safety check ---

    if ~isequal(size(I_crop), size(MaskResized))
        error( ...
            "Image and mask size do not match for position %d", p);
    end

    % --- Mean brightness inside mask ---

    meanBrightness(p) = ...
        mean(double(I_crop(MaskResized)), "omitnan");

    % --- Mask area ---

    maskAreaPixels(p) = sum(MaskResized(:));

    % --- Visualization ---

    if makeFigure

        ax = nexttile;

        imagesc(ax, I_crop);
        axis(ax, "image", "off");
        colormap(ax, "gray");
        clim(ax, [min(I_crop(:)), max(I_crop(:))]);

        % Fijar limites antes de visboundaries
        xlim(ax, [1, size(I_crop, 2)]);
        ylim(ax, [1, size(I_crop, 1)]);
        hold(ax, "on");

        if k == 1
            visboundaries(ax, MaskResized, "Color", "r", "LineWidth", 1);
        else
            visboundaries(ax, MaskResized, "Color", "b", "LineWidth", 1);
        end

        % --- Barra de escala ---

        drawBar = ~isempty(pxSize_um) && ...
            (barOnAllPanels || k == numel(GoodPositions));

        if drawBar
            addScaleBar(ax, barLength_um, pxSize_um, ...
            Location   = "southeast", ...
            FontSize   = 13, ...
            HeightFrac = 0.025, ...
            GapFrac    = 0.35);     % sube a 0.5 para más aire
        end

    end

end

% -------- SAVE FIGURE --------

if saveFigure

    exportgraphics( ...
        fig, ...
        fullfile(outputFolder, "ClusterMasks_Brightness.png"), ...
        "Resolution", 300);

end

end