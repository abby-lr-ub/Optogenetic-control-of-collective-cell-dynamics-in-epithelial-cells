
% -------- INDEX --------

% 0) RESET AND GLOBAL SETTINGS
% 1) DATA SAVING, LOADING AND SELECTION
% 2) MASKS
% 3) BRIGHTNESS
% 4) METRICS
% 5) VIDEOS
% 6) TRACTION MAGNITUDE AND intENERGY INSIDE VS. OUTSIDE
% 7) EXPONENTIAL FITTING

%% ============================================================
%  0) RESET AND GLOBAL SETTINGS
%% ============================================================

% -------- RESET --------

reset(groot)  % reset groot
clearvars     % clear variables from workspace
close all     % close open figure windows
clc           % reset command window

% -------- STYLE --------

set(groot, 'defaultAxesXColor', 'k')
set(groot, 'defaultAxesYColor', 'k')
set(groot, 'defaultTextColor', 'k')
set(groot, 'defaultColorbarColor', 'k')

set(groot, 'defaultAxesFontWeight', 'bold')
set(groot, 'defaultTextFontWeight', 'bold')

set(groot, 'defaultTextInterpreter', 'latex')
set(groot, 'defaultAxesTickLabelInterpreter', 'latex')
set(groot, 'defaultLegendInterpreter', 'latex')

set(groot, 'defaultAxesFontSize', 14)
set(groot, 'defaultTextFontSize', 14)

%% ============================================================
%  1) DATA LOADING, SAVING AND SELECTION
%% ============================================================

% -------- INPUT AND OUTPUT FOLDERS --------

% --- Input ---

dataFolder = "Data";
imageFolder = "MicImages";

% --- Output ---

resultsFolder = "Results";
auxFolder = "Auxiliar";

videosFolder  = fullfile(resultsFolder, "Traction Videos");
figuresFolder = fullfile(resultsFolder, "Figures");

% -.-.-.-.-.-.-.-.-.-.-.-

if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder)
end

if ~exist(auxFolder, 'dir')
    mkdir(auxFolder)
end

if ~exist(videosFolder, 'dir')
    mkdir(videosFolder)
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder)
end

% -.-.-.-.-.-.-.-.-.-.-.-

recomputeMasks = false;
recomputeMetrics = false;

showVideos = true;
saveVideos = true;
showFigs = true;
saveFigs = true;



% -------- DATA LOADING --------

% --- Metadata Biological Information of the experiment ---

MBI_file_name = "F97V-day4-Clusters-MBI.mat";

load(fullfile(dataFolder, MBI_file_name));

% --- TFM data (computed with respect to the trypsinized image) ---

TFM_file_name = "TFM.mat";

load(fullfile(dataFolder, TFM_file_name));

    % X,Y -> 2D grids
    % x,y -> 1D vectors of the grids
    % Tx, Ty -> Tractions [3D matrix, (...) + Time]

% --- Displacements ---

Displacements_file_name = "Displ_corrected.mat";

load(fullfile(dataFolder, Displacements_file_name));

% -------- DATA SELECTION AND IMAGE LOADING --------

% --- Positions ---

GoodPositions = 1:5;

% --- Cluster Images ---

clusterFiles = strings(max(GoodPositions),1);

for p = GoodPositions

    clusterFiles(p) = ...
        "CRY2_Fluo_Red_Stack__f" + ...
        sprintf("%04d", p-1) + ...
        "_t0000.ome.tif";

end

% -------- ACTIVATION SETTINGS --------

total_time = MBI.Time(end) - MBI.Time(1);
total_time_h = hours(total_time);
time_h = hours(MBI.Time - MBI.Time(1));

ctrl_start_h = 2;
actv_h = 8.75;
ctrl_end_h = 2;

actv_pos = 2:5;
ctrl_pos = 1;

%% ============================================================
%  2) MASKS
%% ============================================================

% -------- SAVING FILE --------

maskFile = fullfile(auxFolder, "ClusterMasks.mat");

% -------- CALCULATION ------- (if condition)

if recomputeMasks || ~exist(maskFile, "file") 

    showMaskFigs = false;
    dilationRadius = 30;
    marginRadius = 125;


    ClusterMasks = ComputeClusterMaskTFM(TFM, MBI, imageFolder, clusterFiles, GoodPositions, ...
        showMaskFigs, dilationRadius, marginRadius);

    save(maskFile, "ClusterMasks");

else

    load(maskFile, "ClusterMasks");

end


%% ============================================================
%  3) BRIGHTNESS
%% ============================================================

% -------- BRIGHTNESS PLOT -------- (inside masks)

pxSize_um = 1/3.2462;   % pixel size of the objective/camera used

[meanBrightness, maskAreaPixels] = ...
    MeasureBrightnessInClusterMasks( ...
    imageFolder, clusterFiles, GoodPositions, ...
    maskFile, TFM, MBI, figuresFolder, showFigs, saveFigs, ...
    pxSize_um);


%% ============================================================
%  4) METRICS
%% ============================================================

metricsFile = fullfile(auxFolder, "Metrics.mat");

if recomputeMetrics || ~exist(metricsFile, "file")

    Metrics = ComputeMetrics( ...
        TFM, Displ, ClusterMasks, GoodPositions, time_h, actv_pos, ctrl_pos);

    save(metricsFile, "Metrics")

else

    load(metricsFile, "Metrics")

end

%% ============================================================
%  5) VIDEOS
%% ============================================================

if showVideos || saveVideos

    for p = GoodPositions

        MakeTractionVideo( ...
            TFM{p}, ...
            Displ{p}, ...
            ClusterMasks{p}, ...
            MBI.Time, ...
            p, ...
            actv_pos, ...
            ctrl_start_h, ...
            actv_h, ...
            videosFolder, ...
            showVideos, ...
            saveVideos);

    end

end

%% ============================================================
%  6) TRACTION MAGNITUDE AND intENERGY INSIDE VS. OUTSIDE
%% ============================================================

controlColor = [0.85 0.1 0.1];

coldColors = [ ...
    0.00 0.10 0.45;
    0.00 0.35 0.75;
    0.00 0.60 0.85;
    0.45 0.80 1.00;
    ];

plotColors = [
    controlColor
    coldColors
    ];

% -------- TRACTION MAGNITUDE -------- 

PlotInsideOutside_t( ...
    Metrics.time_h, ...
    Metrics.meanTm_in, ...
    Metrics.meanTm_out, ...
    GoodPositions, ...
    ctrl_start_h, ...
    actv_h, ...
    plotColors, ...
    "Mean $|{\bf T}|$ (Pa)", ...
    "Mean traction magnitude", ...
    fullfile(figuresFolder, "MeanTraction_InsideOutside.png"), ...
    showFigs, ...
    saveFigs);

% -------- ENERGY EXERTED ON THE GEL -------- 

PlotInsideOutside_t( ...
    Metrics.time_h, ...
    Metrics.intE_in_pJ, ...
    Metrics.intE_out_pJ, ...
    GoodPositions, ...
    ctrl_start_h, ...
    actv_h, ...
    plotColors, ...
    "Strain $E$ ($pJ$)", ...
    "Spatially integrated energy", ...
    fullfile(figuresFolder, "IntegratedEnergy_InsideOutside.png"), ...
    showFigs, ...
    saveFigs);


%% -------- CONTROL VS ACTIVATION FACTOR --------

controlIdx = ...
    Metrics.time_h >= 0 & ...
    Metrics.time_h < ctrl_start_h;

activationIdx = ...
    Metrics.time_h >= ctrl_start_h & ...
    Metrics.time_h <= ctrl_start_h + actv_h;

tractionFactor = nan(max(GoodPositions),1);

for p = GoodPositions

    controlMean = mean( ...
        Metrics.meanTm_in(p,controlIdx), ...
        "omitnan");

    activationMean = mean( ...
        Metrics.meanTm_in(p,activationIdx), ...
        "omitnan");

    tractionFactor(p) = ...
        activationMean / controlMean;

end

disp(table( ...
    GoodPositions(:), ...
    tractionFactor(GoodPositions), ...
    'VariableNames', {'Position','TractionFactor'}))



%% ============================================================
%  7) EXPONENTIAL FITTING
%% ============================================================

% -------- AVERAGE OVER THE ACTIVATED POSITIONS --------

actv_pos = 2:5;

Tm_mean = mean( ...
    Metrics.meanTm_in(actv_pos,:), ...
    1, ...
    "omitnan");

Tm_std = std( ...
    Metrics.meanTm_in(actv_pos,:), ...
    0, ...
    1, ...
    "omitnan");

N = numel(actv_pos);

Tm_sem = Tm_std / sqrt(N);

t = Metrics.time_h;

% -------- FIGURE --------

figFit = figure("Color","w");

axFit = axes(figFit);
hold(axFit, "on")

yMin = min(Tm_mean - Tm_sem, [], "omitnan");
yMax = max(Tm_mean + Tm_sem, [], "omitnan");

padding = 0.1 * (yMax - yMin);

if padding == 0
    padding = 1;
end

yLimits = [yMin - padding, yMax + padding];

patch(axFit, ...
    [ctrl_start_h ...
     ctrl_start_h + actv_h ...
     ctrl_start_h + actv_h ...
     ctrl_start_h], ...
    [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
    [0.85 0.85 1], ...
    "EdgeColor","none", ...
    "FaceAlpha",0.5, ...
    "HandleVisibility","off");

fill(axFit, ...
    [t fliplr(t)], ...
    [Tm_mean + Tm_sem ...
     fliplr(Tm_mean - Tm_sem)], ...
    [0.6 0.6 0.6], ...
    "EdgeColor","none", ...
    "FaceAlpha",0.5, ...
    "DisplayName","Mean $\pm$ SEM");

plot(axFit, ...
    t, ...
    Tm_mean, ...
    "k", ...
    "LineWidth",2, ...
    "DisplayName","Mean");

xline(axFit, ctrl_start_h, ...
    "--k", ...
    "LineWidth",1.5, ...
    "HandleVisibility","off");

xline(axFit, ctrl_start_h + actv_h, ...
    "--k", ...
    "LineWidth",1.5, ...
    "HandleVisibility","off");

% -------- ACTIVATION FIT --------

controlFitDuration_h = 2.0;
actFitDuration_h     = 1.0;

tOn = ctrl_start_h;

idxAct = ...
    t >= tOn - controlFitDuration_h & ...
    t <= tOn + actFitDuration_h;

tAct = t(idxAct);
yAct = Tm_mean(idxAct);

% Time zero = activation onset
tAct0 = tAct - tOn;

y0_start = mean(yAct(tAct0 < 0), "omitnan");

fitTypeAct = fittype( ...
    'y0 + A*(1-exp(-max(x,0)/tau))', ...
    'independent', 'x', ...
    'coefficients', {'y0','A','tau'});

optsAct = fitoptions('Method','NonlinearLeastSquares');

optsAct.StartPoint = [ ...
    y0_start, ...
    max(yAct)-y0_start, ...
    0.2];

optsAct.Lower = [0, 0, 0.001];
optsAct.Upper = [Inf, Inf, actFitDuration_h];

[fitAct, gofAct] = fit( ...
    tAct0(:), ...
    yAct(:), ...
    fitTypeAct, ...
    optsAct);

% -------- RELAXATION FIT --------

relControlDuration_h = 0.5;
relFitDuration_h     = 2.0;

tOff = ctrl_start_h + actv_h;

idxRel = ...
    t >= tOff - relControlDuration_h & ...
    t <= tOff + relFitDuration_h;

tRel = t(idxRel);
yRel = Tm_mean(idxRel);

% Time zero = light OFF
tRel0 = tRel - tOff;

yOff_start = mean(yRel(tRel0 < 0), "omitnan");

fitTypeRel = fittype( ...
    'yinf + A*exp(-max(x,0)/tau)', ...
    'independent', 'x', ...
    'coefficients', {'yinf','A','tau'});

optsRel = fitoptions('Method','NonlinearLeastSquares');

optsRel.StartPoint = [ ...
    yRel(end), ...
    yOff_start - yRel(end), ...
    0.5];

optsRel.Lower = [0, 0, 0.001];
optsRel.Upper = [Inf, Inf, relFitDuration_h];

[fitRel, gofRel] = fit( ...
    tRel0(:), ...
    yRel(:), ...
    fitTypeRel, ...
    optsRel);

% -------- PLOT FITS --------

plot(axFit, ...
    tAct, ...
    fitAct(tAct0), ...
    "b--", ...
    "LineWidth", 2, ...
    "DisplayName", ...
    sprintf("$\\tau_{act}$ = %.2f h", fitAct.tau));

plot(axFit, ...
    tRel, ...
    fitRel(tRel0), ...
    "r--", ...
    "LineWidth", 2, ...
    "DisplayName", ...
    sprintf("$\\tau_{rel}$ = %.2f h", fitRel.tau));

% -------- FIGURE FORMATTING --------

ylim(axFit, yLimits)

xlabel(axFit, "Time (h)")
ylabel(axFit, "Mean traction magnitude (Pa)")

title(axFit, "Activated positions (mean $\pm$ SEM)")

legend(axFit, "show", "Location", "best")

box(axFit, "on")
grid(axFit, "on")

% -------- FIT PARAMETERS AND UNCERTAINTIES --------

ciAct = confint(fitAct, 0.95);
ciRel = confint(fitRel, 0.95);

fprintf('\n')
fprintf('================ ACTIVATION FIT ================\n')
fprintf('Formula:\n')
fprintf('T(t) = y0 + A*(1-exp(-max(t,0)/tau))\n\n')

fprintf('Fit window:\n')
fprintf('%.2f h before activation\n', controlFitDuration_h)
fprintf('%.2f h after activation\n\n', actFitDuration_h)

fprintf('y0   = %.3f  [%.3f , %.3f]\n', ...
    fitAct.y0, ciAct(1,1), ciAct(2,1));

fprintf('A    = %.3f  [%.3f , %.3f]\n', ...
    fitAct.A, ciAct(1,2), ciAct(2,2));

fprintf('tau  = %.3f h  [%.3f , %.3f]\n', ...
    fitAct.tau, ciAct(1,3), ciAct(2,3));

fprintf('R2   = %.4f\n', gofAct.rsquare);
fprintf('RMSE = %.4f\n', gofAct.rmse);

fprintf('\n')
fprintf('================ RELAXATION FIT ================\n')
fprintf('Formula:\n')
fprintf('T(t) = yinf + A*exp(-max(t,0)/tau)\n\n')

fprintf('Fit window:\n')
fprintf('%.2f h before light OFF\n', relControlDuration_h)
fprintf('%.2f h after light OFF\n\n', relFitDuration_h)

fprintf('yinf = %.3f  [%.3f , %.3f]\n', ...
    fitRel.yinf, ciRel(1,1), ciRel(2,1));

fprintf('A    = %.3f  [%.3f , %.3f]\n', ...
    fitRel.A, ciRel(1,2), ciRel(2,2));

fprintf('tau  = %.3f h  [%.3f , %.3f]\n', ...
    fitRel.tau, ciRel(1,3), ciRel(2,3));

fprintf('R2   = %.4f\n', gofRel.rsquare);
fprintf('RMSE = %.4f\n', gofRel.rmse);

fprintf('===============================================\n')



%% ============================================================
%  8) COMBINED FIGURE: INSIDE TRACTIONS + EXPONENTIAL FIT
%% ============================================================

% -------- COMMON QUANTITIES --------

t     = Metrics.time_h(:).';
Tm_in = Metrics.meanTm_in;

tOn  = ctrl_start_h;
tOff = ctrl_start_h + actv_h;

N       = numel(actv_pos);
Tm_mean = mean(Tm_in(actv_pos,:), 1, "omitnan");
Tm_sem  = std(Tm_in(actv_pos,:), 0, 1, "omitnan") / sqrt(N);

% -------- FIGURE AND LAYOUT --------

figCombo = figure( ...
    "Color", "w", ...
    "Units", "centimeters", ...
    "Position", [2 2 30 13]);

tl = tiledlayout(figCombo, 1, 2, ...
    "TileSpacing", "loose", ...
    "Padding", "compact");

% ============================================================
%  LEFT PANEL: INDIVIDUAL POSITIONS
% ============================================================

axA = nexttile(tl);
hold(axA, "on")

for p = GoodPositions

    if ismember(p, ctrl_pos)
        posLabel  = sprintf("P%d (ctrl)", p);
        lineWidth = 2;
    else
        posLabel  = sprintf("P%d", p);
        lineWidth = 2;
    end

    plot(axA, t, Tm_in(p,:), ...
        "Color", plotColors(p,:), ...
        "LineWidth", lineWidth, ...
        "DisplayName", posLabel);

end

xline(axA, tOn,  "--k", "LineWidth", 1.5, "HandleVisibility", "off");
xline(axA, tOff, "--k", "LineWidth", 1.5, "HandleVisibility", "off");

xlabel(axA, "Time (h)")
ylabel(axA, "Mean $|{\bf T}|$ (Pa)")

legend(axA, "show", ...
    "Location", "southoutside", ...
    "Orientation", "horizontal", ...
    "NumColumns", numel(GoodPositions), ...
    "Box", "off");

box(axA, "on")
grid(axA, "on")

% ============================================================
%  RIGHT PANEL: MEAN +- SEM + FITS
% ============================================================

axB = nexttile(tl);
hold(axB, "on")

fill(axB, ...
    [t fliplr(t)], ...
    [Tm_mean + Tm_sem, fliplr(Tm_mean - Tm_sem)], ...
    [0.6 0.6 0.6], ...
    "EdgeColor", "none", ...
    "FaceAlpha", 0.5, ...
    "DisplayName", "Mean $\pm$ SEM");

plot(axB, t, Tm_mean, "k", ...
    "LineWidth", 2, ...
    "DisplayName", sprintf("Mean ($N = %d$)", N));

tActPlot = linspace(tOn - controlFitDuration_h, tOn + actFitDuration_h, 300);
tRelPlot = linspace(tOff - relControlDuration_h, tOff + relFitDuration_h, 300);

ciAct = confint(fitAct, 0.95);
ciRel = confint(fitRel, 0.95);

errAct = 0.5 * (ciAct(2,3) - ciAct(1,3));
errRel = 0.5 * (ciRel(2,3) - ciRel(1,3));

plot(axB, tActPlot, fitAct(tActPlot - tOn), "b--", ...
    "LineWidth", 2, ...
    "DisplayName", sprintf("$\\tau_{act} = %.3f \\pm %.3f$ h", fitAct.tau, errAct));

plot(axB, tRelPlot, fitRel(tRelPlot - tOff), "r--", ...
    "LineWidth", 2, ...
    "DisplayName", sprintf("$\\tau_{rel} = %.2f \\pm %.2f$ h", fitRel.tau, errRel));

xline(axB, tOn,  "--k", "LineWidth", 1.5, "HandleVisibility", "off");
xline(axB, tOff, "--k", "LineWidth", 1.5, "HandleVisibility", "off");

xlabel(axB, "Time (h)")
ylabel(axB, "Mean $|{\bf T}|$ (Pa)")

legend(axB, "show", ...
    "Location", "southoutside", ...
    "Orientation", "horizontal", ...
    "NumColumns", 2, ...
    "Box", "off");

box(axB, "on")
grid(axB, "on")

% ============================================================
%  SHARED X-AXIS (data range, independent of the fit curves)
% ============================================================

xLimData = [t(1) t(end)];

xlim(axA, xLimData)
xlim(axB, xLimData)

% ============================================================
%  ACTIVATION BAND (drawn last, spanning the automatic y-limits)
% ============================================================

for ax = [axA axB]

    yl = ylim(ax);

    hBand = patch(ax, ...
        [tOn tOff tOff tOn], ...
        [yl(1) yl(1) yl(2) yl(2)], ...
        [0.85 0.85 1], ...
        "EdgeColor", "none", ...
        "FaceAlpha", 0.5, ...
        "HandleVisibility", "off");

    uistack(hBand, "bottom")   % keep the band behind the curves

    ylim(ax, yl)               % freeze limits so the patch doesn't change them

end

for ax = [axA axB]
    ax.FontSize = 19;
    ax.XTick = 0:2:floor(t(end));
end

% ============================================================
%  EXPORT
% ============================================================

if saveFigs

    exportgraphics(figCombo, ...
        fullfile(figuresFolder, "Clusters_Traction_Inside_and_Fit.png"), ...
        "Resolution", 300);

    exportgraphics(figCombo, ...
        fullfile(figuresFolder, "Clusters_Traction_Inside_and_Fit.pdf"), ...
        "ContentType", "vector");

end