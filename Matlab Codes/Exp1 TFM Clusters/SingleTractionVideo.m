%% ============================================================
%  SIMPLE TRACTION VIDEO — data loading + single-panel movie
%% ============================================================

reset(groot)
clearvars
close all
clc

set(groot, 'defaultAxesFontWeight','bold')

set(groot, 'defaultTextInterpreter', 'latex')
set(groot, 'defaultAxesTickLabelInterpreter', 'latex')
set(groot, 'defaultLegendInterpreter', 'latex')

% -------- FOLDERS --------

dataFolder    = "Data";
auxFolder     = "Auxiliar";
resultsFolder = "Results";
framesSubfolder = "Single Figs";             % still frames -> Results/Single Figs
videosSubfolder = "Single Traction Videos";  % movies       -> Results/Single Traction Videos

if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder)
end

% -------- LOAD --------

load(fullfile(dataFolder, "F97V-day4-Clusters-MBI.mat"));   % MBI
load(fullfile(dataFolder, "TFM.mat"));                      % TFM
load(fullfile(dataFolder, "Displ_corrected.mat"));          % Displ
load(fullfile(auxFolder,  "ClusterMasks.mat"));             % ClusterMasks

% -------- EXPERIMENTAL DESIGN --------

GoodPositions = 1:5;
actv_pos      = 2:5;        % activated positions
ctrl_pos      = 1;          % control position

ctrl_start_h  = 2;
actv_h        = 8.75;

% [linspace(0,1,128)' linspace(0.5,1,128)' ones(128,1) ones(128,1) linspace(1,0,128)' linspace(1,0.25,128)']


% -------- USER SETTINGS --------

p = 4;                      % position to render

cmap_bwr = [linspace(0,1,128)' linspace(0.5,1,128)' ones(128,1); ...
    ones(128,1) linspace(1,0,128)' linspace(1,0.25,128)'];

SimpleTractionVideo( ...
    TFM{p}, Displ{p}, ClusterMasks{p}, MBI.Time, p, ...
    Quantity           = "Tx", ...          % "Tmag" | "Tx" | "Ty" | "Energy"
    Colormap           = cmap_bwr, ...               % or cmap_bwr for Tx ot Ty
    CLim               = [-100 100], ...            % [] for robust auto-scaling   [-100 100] [0 150] [0 30] 
    AxisColor          = "k", ...
    MaskColor          = "k", ...
    MaskLineWidth      = 2.5, ...
    ActivatedPositions = actv_pos, ...
    ActivationWindow   = [ctrl_start_h, ctrl_start_h + actv_h], ...
    ActiveColor        = [0.00 0.40 0.95], ...
    ActiveMaskColor    = [0.00 0.40 0.95], ...
    FontSize           = 25, ...
    AxesSize           = [10.5 10.5], ...
    AxesMargin         = [3.3 3.5], ...
    FigurePosition     = [2 2 18 17], ...
    ShowMask           = true, ...
    YDir               = "reverse", ...
    FrameRate          = 10, ...
    Save               = true, ...
    Show               = true, ...
    SaveFrames         = [1, 4, 12.5], ...
    FramesAreTimes     = true, ...
    FrameResolution    = 400, ...
    ResultsFolder      = resultsFolder, ...
    FramesSubfolder    = framesSubfolder, ...
    VideosSubfolder    = videosSubfolder);

% -------- LOOP OVER ALL POSITIONS (optional) --------
%
% for p = GoodPositions
%     SimpleTractionVideo( ...
%         TFM{p}, Displ{p}, ClusterMasks{p}, MBI.Time, p, ...
%         Quantity           = "Tmag", ...
%         Colormap           = whiteBlue(256), ...
%         CLim               = [0 140], ...
%         ActivatedPositions = actv_pos, ...
%         ActivationWindow   = [ctrl_start_h, ctrl_start_h + actv_h], ...
%         FontSize           = 16, ...
%         Show               = false, ...
%         ResultsFolder      = resultsFolder, ...
%         FramesSubfolder    = framesSubfolder, ...
%         VideosSubfolder    = videosSubfolder);
% end


%% ============================================================
%  MAIN FUNCTION
%% ============================================================

function SimpleTractionVideo(TFMp, Displp, Maskp, Time, p, opts)

arguments
    TFMp
    Displp
    Maskp
    Time
    p (1,1) double

    % --- Field and colors ---
    opts.Quantity           (1,1) string  = "Tmag"
    opts.Colormap                         = parula(256)
    opts.CLim                             = []

    % --- Axis / mask appearance (light OFF, control) ---
    opts.AxisColor                        = [0 0 0]
    opts.MaskColor                        = [0 0 0]
    opts.MaskLineWidth      (1,1) double  = 1.5
    opts.AxisLineWidth      (1,1) double  = 1.0

    % --- Activation ---
    opts.ActivatedPositions (1,:) double  = []
    opts.ActivationWindow   (1,:) double  = []
    opts.ActiveColor                      = [0.00 0.60 0.85]
    opts.ActiveMaskColor                  = [0.00 0.60 0.85]
    opts.ShowLightState     (1,1) logical = true

    % --- Layout ---
    opts.FontSize           (1,1) double  = 14
    opts.FigureColor                      = [1 1 1]
    opts.FigurePosition     (1,4) double  = [2 2 16 15]   % cm
    opts.AxesSize           (1,2) double  = [10 10]       % cm, data field
    opts.AxesMargin         (1,2) double  = [2.5 2.0]     % cm, from bottom-left
    opts.ShowMask           (1,1) logical = true
    opts.YDir               (1,1) string  = "reverse"

    % --- Output ---
    opts.FrameRate          (1,1) double  = 10
    opts.Show               (1,1) logical = true
    opts.Save               (1,1) logical = true
    opts.ResultsFolder      (1,1) string  = "Results"
    opts.FramesSubfolder    (1,1) string  = "Single Figs"
    opts.VideosSubfolder    (1,1) string  = "Single Traction Videos"

    % --- Still frames ---
    opts.SaveFrames         (1,:) double  = []
    opts.FramesAreTimes     (1,1) logical = false
    opts.FrameResolution    (1,1) double  = 300
    opts.SaveFramesPDF      (1,1) logical = false
end

% ============================================================
%  1) FIELD CONSTRUCTION
% ============================================================

X  = TFMp.X;
Y  = TFMp.Y;
Tx = TFMp.Tx;
Ty = TFMp.Ty;

if opts.Quantity == "Energy"

    Ux = double(Displp.Dx);
    Uy = double(Displp.Dy);

    if ~isequal(size(Ux), size(Tx))
        error("Displacements (%s) and tractions (%s) have different sizes.", ...
            mat2str(size(Ux)), mat2str(size(Tx)));
    end

end

switch opts.Quantity

    case "Tmag"
        F        = sqrt(Tx.^2 + Ty.^2);
        cbLabel  = "Tractions, $|{\bf T}|$ (Pa)";
        titleStr = "Traction magnitude";
        signed   = false;

    case "Tx"
        F        = Tx;
        cbLabel  = "Tractions, $T_x$ (Pa)";
        titleStr = "x-Tractions";
        signed   = true;

    case "Ty"
        F        = Ty;
        cbLabel  = "Tractions, $T_y$ (Pa)";
        titleStr = "y-Tractions";
        signed   = true;

    case "Energy"
        F        = 0.5 * (Tx.*Ux + Ty.*Uy);
        cbLabel  = "Local strain energy (Pa $\mu$m)";
        titleStr = "Local strain energy density";
        signed   = false;

    otherwise
        error("Quantity must be Tmag, Tx, Ty or Energy.")

end

nT = size(F, 3);

% ============================================================
%  2) ACTIVATION STATUS OF THIS POSITION
% ============================================================

isActivatedPosition = ...
    ~isempty(opts.ActivatedPositions) && ...
    ~isempty(opts.ActivationWindow)   && ...
    ismember(p, opts.ActivatedPositions);

if isActivatedPosition
    posTag = "activated";
else
    posTag = "control";
end

% ============================================================
%  3) COLOR LIMITS (fixed for the whole movie)
% ============================================================

if isempty(opts.CLim)

    v  = sort(F(isfinite(F)));

    cl = [ v(max(1, round(0.01*numel(v)))), ...
           v(min(numel(v), round(0.99*numel(v)))) ];

    if cl(2) <= cl(1)
        cl(2) = cl(1) + eps;
    end

else
    cl = opts.CLim;
end

if signed
    cl = max(abs(cl)) * [-1 1];
end

% ============================================================
%  4) TIME VECTOR
% ============================================================

if isdatetime(Time) || isduration(Time)
    tDur = Time - Time(1);
else
    tDur = hours(double(Time(:)) - double(Time(1)));
end

tDur.Format = 'hh:mm:ss';

t_h = hours(tDur);          % numeric, for ON/OFF comparison and frame lookup

% ============================================================
%  5) FRAMES TO EXPORT AS STILL IMAGES
% ============================================================

if isempty(opts.SaveFrames)

    frameIdx = [];

elseif opts.FramesAreTimes

    frameIdx = zeros(1, numel(opts.SaveFrames));

    for i = 1:numel(opts.SaveFrames)
        [~, frameIdx(i)] = min(abs(t_h - opts.SaveFrames(i)));
    end

    frameIdx = unique(frameIdx);

else

    frameIdx = unique(opts.SaveFrames);
    frameIdx = frameIdx(frameIdx >= 1 & frameIdx <= nT);

end

% ============================================================
%  6) FIGURE SETUP
% ============================================================

fig = figure( ...
    "Color", opts.FigureColor, ...
    "Units", "centimeters", ...
    "Position", opts.FigurePosition, ...
    "Visible", matlab.lang.OnOffSwitchState(opts.Show));

ax = axes(fig);
hold(ax, "on")

colormap(ax, opts.Colormap)

hImg = imagesc(ax, X(1,:), Y(:,1), F(:,:,1));

set(ax, "YDir", opts.YDir)
axis(ax, "image")
clim(ax, cl)

xlabel(ax, "$x$ ($\mu$m)")
ylabel(ax, "$y$ ($\mu$m)")

cb = colorbar(ax);
cb.Label.String         = cbLabel;
cb.Label.Interpreter    = "latex";
cb.TickLabelInterpreter = "latex";
cb.FontSize             = opts.FontSize;

ax.FontSize  = opts.FontSize;
ax.LineWidth = opts.AxisLineWidth;

box(ax, "on")

% -------- Fixed axes size (font-independent) --------

ax.Units    = "centimeters";
ax.Position = [opts.AxesMargin(1), opts.AxesMargin(2), ...
               opts.AxesSize(1),   opts.AxesSize(2)];

hMask = gobjects(1);

% ============================================================
%  7) OUTPUT FOLDERS AND VIDEO WRITER
% ============================================================

if ~exist(opts.ResultsFolder, "dir")
    mkdir(opts.ResultsFolder)
end

% Still frames and movies go to dedicated subfolders inside ResultsFolder
framesFolder = fullfile(opts.ResultsFolder, opts.FramesSubfolder);
videosFolder = fullfile(opts.ResultsFolder, opts.VideosSubfolder);

if ~isempty(frameIdx) && ~exist(framesFolder, "dir")
    mkdir(framesFolder)
end

if opts.Save && ~exist(videosFolder, "dir")
    mkdir(videosFolder)
end

if opts.Save

    fname = sprintf("P%d_%s_%s.mp4", p, opts.Quantity, posTag);

    vw = VideoWriter(fullfile(videosFolder, fname), "MPEG-4");
    vw.FrameRate = opts.FrameRate;
    vw.Quality   = 95;

    open(vw)

end

% ============================================================
%  8) FRAME LOOP
% ============================================================

for k = 1:nT

    kk = min(k, numel(tDur));

    % -------- Light state --------

    isOn = isActivatedPosition && ...
           t_h(kk) >= opts.ActivationWindow(1) && ...
           t_h(kk) <= opts.ActivationWindow(2);

    if isOn
        axCol    = opts.ActiveColor;
        maskCol  = opts.ActiveMaskColor;
        stateStr = "light ON";
    else
        axCol    = opts.AxisColor;
        maskCol  = opts.MaskColor;
        stateStr = "light OFF";
    end

    % -------- Scalar field --------

    set(hImg, "CData", F(:,:,k));

    % -------- Mask contour --------

    if opts.ShowMask

        M = maskFrame(Maskp, k);

        if ~isempty(M)

            if isgraphics(hMask)
                delete(hMask)
            end

            [~, hMask] = contour(ax, X, Y, double(M), [0.5 0.5], ...
                "Color", maskCol, ...
                "LineWidth", opts.MaskLineWidth);

        end

    end

    % -------- Title --------

    if opts.ShowLightState && isActivatedPosition
        title(ax, sprintf("$t = $ %s  --  %s", string(tDur(kk)), stateStr));
    else
        title(ax, sprintf("$t = $ %s", string(tDur(kk))));
    end

    % -------- Apply state-dependent colors --------

    ax.XColor       = axCol;
    ax.YColor       = axCol;
    ax.Title.Color  = axCol;
    ax.XLabel.Color = axCol;
    ax.YLabel.Color = axCol;

    cb.Color        = axCol;
    cb.Label.Color  = axCol;

    drawnow

    % -------- Export still frame --------

    if ismember(k, frameIdx)

        stillName = sprintf("P%d_%s_%s_frame%03d_t%05.2fh", ...
            p, opts.Quantity, posTag, k, t_h(kk));

        exportgraphics(fig, ...
            fullfile(framesFolder, stillName + ".png"), ...
            "Resolution", opts.FrameResolution);

        if opts.SaveFramesPDF
            exportgraphics(fig, ...
                fullfile(framesFolder, stillName + ".pdf"), ...
                "ContentType", "vector");
        end

    end

    % -------- Write video frame --------

    if opts.Save
        writeVideo(vw, getframe(fig));
    end

end

if opts.Save
    close(vw)
end

if ~opts.Show
    close(fig)
end

end


%% ============================================================
%  LOCAL HELPERS
%% ============================================================

function M = maskFrame(Maskp, k)

M = [];

if isstruct(Maskp)
    for n = ["inside","in","mask","clusterMask"]
        if isfield(Maskp, n)
            Maskp = Maskp.(n);
            break
        end
    end
end

if ~(isnumeric(Maskp) || islogical(Maskp))
    return
end

if ndims(Maskp) == 3
    M = Maskp(:,:,min(k, size(Maskp,3)));
else
    M = Maskp;
end

end

% -.-.-.-.-.-.-.-.-.-.-.-

function cmap = whiteBlue(n, endColor)

if nargin < 2
    endColor = [0.05 0.25 0.55];
end

cmap = [ linspace(1, endColor(1), n)', ...
         linspace(1, endColor(2), n)', ...
         linspace(1, endColor(3), n)' ];

end

% -.-.-.-.-.-.-.-.-.-.-.-

function cmap = redBlue(n)

m  = round(n/2);

lo = [linspace(0.02,1,m)', linspace(0.19,1,m)', linspace(0.60,1,m)'];
hi = [ones(m,1), linspace(1,0.10,m)', linspace(1,0.15,m)'];

cmap = [lo; hi(2:end,:)];

end