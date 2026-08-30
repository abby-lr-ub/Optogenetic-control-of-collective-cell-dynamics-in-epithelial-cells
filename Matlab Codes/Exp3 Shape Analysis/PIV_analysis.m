%% ============================================================
%  STRIPE CONTRACTION ANALYSIS
%
%  Standalone equivalent of CalculateRegionFlow.m +
%  Script_StudyContraction.m, without the MBI / CZMBI framework.
%
%  ---------- SIGN CONVENTION ---------------------------------
%  With CFG.contractionPositive = true (default):
%     u_edge > 0  ->  the stripe edges move INWARD  (contraction)
%     dW    > 0   ->  the stripe becomes NARROWER
%     dW = 2 * u_edge
%  Set CFG.contractionPositive = false for the outward-positive
%  convention, in which contraction is negative.
%% ============================================================

reset(groot)
clearvars
close all
clc

rng(0)                                     % reproducible box-plot jitter

load(fullfile('Data','PIV.mat'))           % -> PIV (cell array)

% All output (PNGs, .csv and .mat) goes to Results/PIV, next to the
% Results/ShapeAnalysis folder written by the shape script.

resultsFolder = fullfile('Results','PIV');

if ~exist(resultsFolder,'dir')
    mkdir(resultsFolder);
end

%% ============================================================
%  CONFIGURATION
%% ============================================================

% ---- timing / protocol -------------------------------------
%  Same numbers as in ShapeAnalysis_WeightedByCells_SEM.m. Keep them in
%  sync; the frame indices are derived, never hard-coded.
%
%     0 -  2 h : basal
%     2 - 12 h : optogenetic activation
%    12 - 16 h : recovery

CFG.frameDuration_min    = 3;
CFG.dt_h                 = CFG.frameDuration_min / 60;

CFG.preControl_h         = 2;
CFG.activation_h         = 10;
CFG.postControl_h        = 4;

% ---- region ------------------------------------------------
CFG.regionType           = "Rectangular";
CFG.stripeIsVertical     = true;      % true: long in y, 1D coord is x
CFG.Radius1D             = 150;       % full stripe width, um
CFG.regionCenterX_um     = 0;
CFG.regionCenterY_um     = 0;

% ---- units -------------------------------------------------
CFG.pivUnit              = "um_per_frame";
CFG.coordinateUnit       = "um";
CFG.centerCoordinates    = true;
CFG.duIsCumulative       = false;

% ---- PIV metadata (for the Eulerian validity check) ---------
CFG.pivWindow_um         = [];        % interrogation window size, um.
                                      % [] -> assume 2 grid spacings.

% ---- sign convention ---------------------------------------
%
%  false : outward positive, so CONTRACTION IS NEGATIVE (default).
%  true  : inward positive, so contraction is a positive number.
%
%  perPositionFigContractionPositive overrides the convention for the
%  per-position figures ONLY. Leave it empty to follow the global
%  setting; the script reports at run time if the two differ.

CFG.contractionPositive               = false;
CFG.perPositionFigContractionPositive = [];

% ---- optional corrections ----------------------------------
%
%  driftRefDistance_um also sets the inner edge of the FAR field used
%  as drift reference and as MSD control zone. It must lie beyond the
%  mechanical influence of the stripe: check the decay length l0
%  printed at the end and increase it if l0 is comparable.

CFG.removeGlobalDrift    = false;
CFG.driftRefDistance_um  = 150;
CFG.smoothFrames         = 1;

% ---- divergence --------------------------------------------
CFG.divReferenceFrame    = [];        % [] = activation start
CFG.divSmoothing_um      = 25;
CFG.divLimits            = 0.15;

% ---- radial band profile / decay length --------------------
CFG.radialBandWidth_um   = 6;
CFG.profileNoiseFloor_um = 0.15;      % ignore profile points below this
CFG.l0FitMaxDist_um      = [];        % [] = out to the edge of the field

% ---- MSD ---------------------------------------------------
%
%  The MSD is time-averaged over reference times t0, which presupposes
%  a STATIONARY process. This experiment is not (ACTV on at frame 40,
%  off at frame 240), so it is computed separately in each window.
%
%  Drift removal is mandatory here: u_edge is a difference between the
%  two stripe edges and a rigid translation cancels out, but the MSD of
%  a drifting field picks up a spurious ballistic (tau^2) term.

CFG.msdRemoveDrift    = true;
CFG.msdMaxLagFraction = 0.4;      % max lag as a fraction of the window
CFG.msdFitLags_h      = [];       % [] -> common range, auto (see below)
CFG.msdFitLagMin_h    = 0.15;     % lower end of the auto range
CFG.msdFitOffset      = false;    % true -> fit MSD = 4 G tau^a + 2 eps^2

CFG.msdWindowsDef = { 'Basal', [0            CFG.preControl_h]
                      'ACTV',  [CFG.preControl_h  CFG.preControl_h+CFG.activation_h]
                      'Post',  [CFG.preControl_h+CFG.activation_h  ...
                                CFG.preControl_h+CFG.activation_h+CFG.postControl_h] };

%% ---- PLOTTING / SIZING ------------------------------------
%
%  The exported size is CFG.figWidth_cm x (CFG.rowHeight_cm * nRows),
%  honoured regardless of screen size. Font sizes are in absolute
%  points and do NOT scale with the figure: if rowHeight_cm changes by
%  a factor k, scale the font sizes by roughly k too.

CFG.ULimits              = 8;         % kymograph colour limits, um
CFG.quiverSkip           = 3;
CFG.quiverRef_um         = 5;         % length of the reference arrow
CFG.quiverRefNodes       = 1.5;       % ...drawn as this many grid steps

CFG.figWidth_cm          = 32;
CFG.rowHeight_cm         = 6;         % panel height

CFG.preserveAspect       = false;     % true -> geometrically faithful maps

CFG.fontSizeAxes         = 9;
CFG.fontSizeLabel        = 9;
CFG.fontSizeTitle        = 11;
CFG.lineWidthAxes        = 0.5;

% ---- statistical annotations on the box plots ---------------
%  All vertical offsets are fractions of the DATA range of the panel.
%  Raise statBracketGap if the bracket sits on the points, raise
%  statTextGap if the p-value sits on the bracket, raise statHeadroom
%  if the text is clipped by the top of the axes.

CFG.statStarGap          = 0.05;      % stars above each group's points
CFG.statBracketGap       = 0.18;      % bracket above the data
CFG.statTickHeight       = 0.025;     % length of the bracket end ticks
CFG.statTextGap          = 0.03;      % p-value above the bracket
CFG.statHeadroom         = 0.18;      % blank space above everything
CFG.fontSizeStar         = 14;
CFG.fontSizeStat         = 12;

CFG.exportResolution     = 200;       % dpi for the PNG
CFG.exportPDF            = false;     % vector PDF can get very heavy

% ---- groups ------------------------------------------------
Groups(1).Name      = "D1-low Actv";
Groups(1).Positions = 1:12;
Groups(1).Color     = [0.85 0.33 0.10];

Groups(2).Name      = "D1-low Ctrl";
Groups(2).Positions = 13:24;
Groups(2).Color     = [0.00 0.45 0.74];

CyanTransparent = [0 1 1 0.5];

% ---- style shared with ShapeAnalysis_WeightedByCells_SEM.m ---
%
%  The two analyses describe the same experiment, so the activation
%  window is drawn the same way in both: shaded in the ACTV blue, with
%  dashed black lines at its edges.

CFG.actvShadeColor = [0.2 0.4 1];
CFG.actvShadeAlpha = 0.12;

%% ============================================================
%  DERIVED TIMING  --  never hard-code frame numbers
%% ============================================================

nFiles = numel(PIV);
Tref   = size(PIV{1}.dU,3);

% PIV index k is the displacement accumulated after k inter-frame
% intervals, i.e. it is time-stamped at the END of interval k.
% Image frame k of the segmentation corresponds to PIV index k-1.
Time = (1:Tref)' * CFG.dt_h;

CFG.activationStartFrame = round(CFG.preControl_h / CFG.dt_h);
CFG.activationEndFrame   = round((CFG.preControl_h + CFG.activation_h) / CFG.dt_h);
CFG.experimentEndFrame   = round((CFG.preControl_h + CFG.activation_h + ...
                                  CFG.postControl_h) / CFG.dt_h);

if CFG.experimentEndFrame > Tref
    warning(['Protocol implies %d frames but the PIV has %d. ' ...
             'Clamping the analysis to the available frames.'], ...
            CFG.experimentEndFrame, Tref);
    CFG.experimentEndFrame = Tref;
end

if CFG.activationEndFrame >= Tref
    error(['The activation window reaches the last PIV frame; there is ' ...
           'no recovery phase to analyse. Check the protocol times.'])
end

if isempty(CFG.divReferenceFrame)
    CFG.divReferenceFrame = CFG.activationStartFrame;
end

ActTimes = [CFG.activationStartFrame CFG.activationEndFrame] * CFG.dt_h;

% ---- MSD windows, in frames --------------------------------
nWin       = size(CFG.msdWindowsDef,1);
CFG.msdWindows = cell(nWin,2);

for w = 1:nWin
    t1 = CFG.msdWindowsDef{w,2}(1);
    t2 = CFG.msdWindowsDef{w,2}(2);
    f1 = max(1,    round(t1/CFG.dt_h) + 1);
    f2 = min(Tref, round(t2/CFG.dt_h));
    CFG.msdWindows{w,1} = CFG.msdWindowsDef{w,1};
    CFG.msdWindows{w,2} = [f1 f2];
end

% ---- COMMON MSD fit range ----------------------------------
%
%  Every window must be fitted over the SAME lag range or the exponents
%  are not comparable. The upper limit is set by the shortest window.

winLen    = cellfun(@(v) v(2)-v(1)+1, CFG.msdWindows(:,2));
maxLagAll = floor(CFG.msdMaxLagFraction * min(winLen));

if maxLagAll < 4
    error(['The shortest MSD window (%d frames) supports only %d lags. ' ...
           'Lengthen the window or raise msdMaxLagFraction.'], ...
          min(winLen), maxLagAll);
end

if isempty(CFG.msdFitLags_h)
    CFG.msdFitLags_h = [CFG.msdFitLagMin_h, maxLagAll * CFG.dt_h];
else
    if CFG.msdFitLags_h(2) > maxLagAll*CFG.dt_h
        warning(['Requested fit range reaches %.2f h but the shortest ' ...
                 'window only reaches %.2f h. Truncating.'], ...
                CFG.msdFitLags_h(2), maxLagAll*CFG.dt_h);
        CFG.msdFitLags_h(2) = maxLagAll * CFG.dt_h;
    end
end

% ---- sign convention ---------------------------------------
[CFG.signFactor, CFG.uEdgeLabel, CFG.signNote] = ...
        signConvention(CFG.contractionPositive);

if isempty(CFG.perPositionFigContractionPositive)
    CFG.perPositionFigContractionPositive = CFG.contractionPositive;
end

% display-only factor applied to the per-position panels, relative to
% the convention the numbers are already stored in
if CFG.perPositionFigContractionPositive == CFG.contractionPositive
    ppFactor = +1;
else
    ppFactor = -1;
end

[~, ppLabel, ppNote] = signConvention(CFG.perPositionFigContractionPositive);

% ---- group bookkeeping -------------------------------------
groupIdx = zeros(1,nFiles);

for g = 1:numel(Groups)
    if any(Groups(g).Positions > nFiles) || any(Groups(g).Positions < 1)
        error('Group "%s" refers to positions outside 1:%d.', ...
              Groups(g).Name, nFiles);
    end
    if any(groupIdx(Groups(g).Positions) > 0)
        error('Position assigned to more than one group.');
    end
    groupIdx(Groups(g).Positions) = g;
end

if any(groupIdx == 0)
    warning('%d position(s) are not assigned to any group and will be ignored.', ...
            nnz(groupIdx == 0));
end

fprintf('Protocol: basal 1-%d, ACTV %d-%d, post %d-%d (dt = %.3f h)\n', ...
        CFG.activationStartFrame, ...
        CFG.activationStartFrame+1, CFG.activationEndFrame, ...
        CFG.activationEndFrame+1,   CFG.experimentEndFrame, CFG.dt_h);
fprintf('Sign convention: %s\n', CFG.signNote);

if ppFactor == -1
    fprintf(['  NOTE: the per-position figures use the OPPOSITE convention ' ...
             '(%s).\n        Everything else -- box plots, profiles, l0, ' ...
             'summary table -- uses the global one.\n'], ppNote);
end
fprintf('Common MSD fit range: %.2f - %.2f h\n\n', ...
        CFG.msdFitLags_h(1), CFG.msdFitLags_h(2));

%% ============================================================
%  ANALYSE EVERY POSITION
%% ============================================================

Analyses = cell(nFiles,1);

for f = 1:nFiles
    Analyses{f} = CalculateStripeFlow(PIV{f}, CFG, Tref);
end

Analyses = [Analyses{:}];

A1 = Analyses(1);

fprintf('--- geometry check (position 1) ---\n');
fprintf('grid spacing dx / dy   : %.2f / %.2f um\n', A1.dx, A1.dy);
fprintf('x range                : %.1f to %.1f um\n', A1.x1D(1), A1.x1D(end));
fprintf('y range                : %.1f to %.1f um\n', A1.y1D(1), A1.y1D(end));
fprintf('field aspect (w/h)     : %.2f\n', range(A1.x1D)/range(A1.y1D));
fprintf('nodes on left edge     : %d\n', A1.nLeft);
fprintf('nodes on right edge    : %d\n', A1.nRight);
fprintf('nodes inside / near / far : %d / %d / %d\n', ...
        A1.nIn, A1.nNear, A1.nFar);
fprintf('divergence sigma       : %.1f grid nodes\n', A1.divSigmaNodes);
fprintf('-----------------------------------\n');

if A1.nLeft == 0 || A1.nRight == 0
    error(['The region edges do not intersect the PIV grid. Check ' ...
           'coordinateUnit, centerCoordinates and CFG.Radius1D.'])
end

if A1.nFar < 10
    warning(['Only %d far-field nodes beyond %.0f um. The drift ' ...
             'reference and the far-field MSD control are unreliable; ' ...
             'lower CFG.driftRefDistance_um or accept that the far ' ...
             'field is not resolved.'], A1.nFar, CFG.driftRefDistance_um);
end

% ---- data quality ------------------------------------------
nanFrac = [Analyses.nanFraction];

fprintf('NaN fraction in dU/dV  : median %.2f%%, max %.2f%%\n', ...
        100*median(nanFrac), 100*max(nanFrac));

if max(nanFrac) > 0.05
    warning(['Up to %.1f%% of the PIV field is NaN. cumsum(...,''omitnan'') ' ...
             'treats a NaN as zero displacement, so those trajectories are ' ...
             'artificially frozen and the MSD is biased low.'], 100*max(nanFrac));
end

% ---- Eulerian validity -------------------------------------
%
%  Integrating displacement at a FIXED grid node is only a trajectory
%  while the accumulated displacement stays small compared with the
%  interrogation window.

if isempty(CFG.pivWindow_um)
    winSize_um = 2 * mean(abs([A1.dx A1.dy]));
    winSrc     = 'assumed = 2 grid spacings';
else
    winSize_um = CFG.pivWindow_um;
    winSrc     = 'from CFG.pivWindow_um';
end

wActv  = find(strcmpi(CFG.msdWindows(:,1), 'ACTV'), 1);
if isempty(wActv), wActv = 1; end

rmsMax = sqrt(max(arrayfun(@(a) max(a.msd(wActv).raw_in), Analyses)));

fprintf('Eulerian check: sqrt(MSD) at the longest ACTV lag = %.2f um\n', rmsMax);
fprintf('                PIV interrogation window = %.2f um (%s)\n', ...
        winSize_um, winSrc);

if rmsMax > 0.5*winSize_um
    warning(['Accumulated displacement reaches %.0f%% of the interrogation ' ...
             'window. The integrated trajectories are no longer Lagrangian; ' ...
             'report this and cross-check against segmented cell tracks.'], ...
            100*rmsMax/winSize_um);
end

fprintf('-----------------------------------\n\n');

Contractions = [Analyses.Contraction];
Recoveries   = [Analyses.Recovery];
RecFractions = [Analyses.RecoveredFraction];
L0s          = [Analyses.l0_um];

%% ============================================================
%  PER-POSITION FIGURES, ONE PER GROUP
%% ============================================================

for g = 1:numel(Groups)

    positions = Groups(g).Positions;
    nRows     = numel(positions);

    figSizeCm = [CFG.figWidth_cm, CFG.rowHeight_cm * nRows];

    fprintf('Plotting group %s (%d positions), %.1f x %.1f cm...\n', ...
            Groups(g).Name, nRows, figSizeCm(1), figSizeCm(2));
    tic

    hFig = figure('Visible','off', ...
                  'Units','centimeters', ...
                  'Color','w', ...
                  'Name',char(Groups(g).Name));

    hFig.Position = [0 0 figSizeCm];

    % MATLAB clamps Position to the screen. The export below uses
    % figSizeCm, not the clipped Position.
    if abs(hFig.Position(4) - figSizeCm(2)) > 0.1
        fprintf(['  note: on-screen height clipped to %.1f cm by the ' ...
                 'display; export still uses %.1f cm.\n'], ...
                hFig.Position(4), figSizeCm(2));
    end

    set(hFig, 'DefaultAxesFontSize',      CFG.fontSizeAxes, ...
              'DefaultAxesLineWidth',     CFG.lineWidthAxes, ...
              'DefaultAxesTickLength',    [0.015 0.015], ...
              'DefaultTextFontSize',      CFG.fontSizeLabel, ...
              'DefaultColorbarFontSize',  CFG.fontSizeAxes);

    tiledlayout(hFig, nRows, 4, 'Padding','tight', 'TileSpacing','loose');

    xTicksMap = niceTicks(A1.x1D);

    % common y limits for column 4, so rows are comparable
    allB       = ppFactor * [Analyses(positions).U1D_Boundary];
    yLimCommon = paddedLimits(allB(:));

    for i = 1:nRows

        f       = positions(i);
        A       = Analyses(f);
        isFirst = (i == 1);
        isLast  = (i == nRows);

        %% ---- 1) QUIVER of the displacement DURING ACTIVATION ----
        %
        %  Fixed scale, not AutoScale: an arrow of CFG.quiverRef_um is
        %  drawn as CFG.quiverRefNodes grid steps, and the reference
        %  arrow in the corner makes the panel quantitative.

        ax = nexttile;
        hold(ax,'on')

        s      = CFG.quiverSkip;
        arrowK = CFG.quiverRefNodes * s * mean(abs([A.dx A.dy])) / CFG.quiverRef_um;

        quiver(ax, A.X(1:s:end,1:s:end), A.Y(1:s:end,1:s:end), ...
                   arrowK*A.U_act(1:s:end,1:s:end), ...
                   arrowK*A.V_act(1:s:end,1:s:end), ...
               0, 'Color',[0.85 0.33 0.10]);

        plotRegion(ax, CFG, CyanTransparent);

        xlim(ax, A.x1D([1 end]))
        ylim(ax, A.y1D([1 end])')
        setPanelAspect(ax, CFG)

        ax.XTick = xTicksMap;
        ax.YTick = niceTicks(A.y1D);

        ylabel(ax,'$y$ ($\mu$m)','Interpreter','latex', ...
               'FontSize',CFG.fontSizeLabel)

        if isLast
            xlabel(ax,'$x$ ($\mu$m)','Interpreter','latex', ...
                   'FontSize',CFG.fontSizeLabel)
        else
            ax.XTickLabel = [];
        end

        text(ax, 0.02, 0.94, sprintf('P%d', f), ...
             'Units','normalized', 'FontSize',CFG.fontSizeTitle, ...
             'FontWeight','bold', 'VerticalAlignment','top');

        drawScaleArrow(ax, arrowK*CFG.quiverRef_um, ...
                       sprintf('%g \\mum', CFG.quiverRef_um), CFG);

        if isFirst
            title(ax,'PIV displacement (ACTV)','FontSize',CFG.fontSizeTitle)
        end

        box(ax,'on')
        hold(ax,'off')

        %% ---- 2) DIVERGENCE map (= areal strain) ----
        ax = nexttile;
        hold(ax,'on')

        imagesc(ax, A.x1D, A.y1D, A.divUV, [-1 1]*CFG.divLimits);
        set(ax,'YDir','normal')

        colormap(ax, neutralWhiteMap)

        cb = tileColorbar(ax, CFG);

        if isFirst
            cb.Label.Interpreter = 'latex';
            cb.Label.String = '$\nabla\!\cdot\vec{u}$';
        end

        plotRegion(ax, CFG, CyanTransparent);

        xlim(ax, A.x1D([1 end]))
        ylim(ax, A.y1D([1 end])')
        setPanelAspect(ax, CFG)

        ax.XTick = xTicksMap;
        ax.YTick = niceTicks(A.y1D);
        ax.YTickLabel = [];

        if isLast
            xlabel(ax,'$x$ ($\mu$m)','Interpreter','latex', ...
                   'FontSize',CFG.fontSizeLabel)
        else
            ax.XTickLabel = [];
        end

        if isFirst
            title(ax,'areal strain (ACTV)','FontSize',CFG.fontSizeTitle)
        end

        box(ax,'on')
        hold(ax,'off')

        %% ---- 3) KYMOGRAPH of the 1D displacement profile ----
        ax = nexttile;
        hold(ax,'on')

        imagesc(ax, A.x1D, Time, A.U1D', [-1 1]*CFG.ULimits);
        set(ax,'YDir','normal')

        colormap(ax, neutralWhiteMap)

        cb = tileColorbar(ax, CFG);

        if isFirst
            cb.Label.Interpreter = 'latex';
            cb.Label.String = '$u_x$ ($\mu$m)';
        end

        rectangle('Parent',ax, ...
                  'Position',[-CFG.Radius1D/2, ActTimes(1), ...
                               CFG.Radius1D,   diff(ActTimes)], ...
                  'LineWidth',1.2, 'EdgeColor',CyanTransparent);

        xlim(ax, A.x1D([1 end]))
        ylim(ax, Time([1 end])')

        ax.XTick = xTicksMap;

        ylabel(ax,'$t$ (h)','Interpreter','latex', ...
               'FontSize',CFG.fontSizeLabel)

        if isLast
            xlabel(ax,'$x$ ($\mu$m)','Interpreter','latex', ...
                   'FontSize',CFG.fontSizeLabel)
        else
            ax.XTickLabel = [];
        end

        if isFirst
            title(ax,'1D displacement kymograph','FontSize',CFG.fontSizeTitle)
        end

        box(ax,'on')
        hold(ax,'off')

        %% ---- 4) BOUNDARY displacement over time ----
        ax = nexttile;
        hold(ax,'on')

        patch('Parent',ax, ...
              'XData',[ActTimes(1) ActTimes(2) ActTimes(2) ActTimes(1)], ...
              'YData',[yLimCommon(1) yLimCommon(1) ...
                       yLimCommon(2) yLimCommon(2)], ...
              'FaceColor',CyanTransparent(1:3), 'EdgeColor','none', ...
              'FaceAlpha',0.20, 'HandleVisibility','off');

        plot(ax, Time, ppFactor * A.U1D_Boundary, ...
             'Color',[0.85 0.33 0.10], 'LineWidth',1.2);

        yline(ax, 0, 'Color',[0.5 0.5 0.5], 'LineWidth',0.5);

        xlim(ax, Time([1 end])')
        ylim(ax, yLimCommon)

        if isFirst
            ylabel(ax, ppLabel, 'Interpreter','latex', ...
                   'FontSize',CFG.fontSizeLabel)
        end

        if isLast
            xlabel(ax,'$t$ (h)','Interpreter','latex', ...
                   'FontSize',CFG.fontSizeLabel)
        else
            ax.XTickLabel = [];
        end

        text(ax, 0.98, 0.06, ...
             sprintf('contr = %.2f \\mum | recov = %.0f%%', ...
                     ppFactor*A.Contraction, 100*A.RecoveredFraction), ...
             'Units','normalized', 'FontSize',CFG.fontSizeLabel, ...
             'HorizontalAlignment','right', 'VerticalAlignment','bottom');

        if isFirst
            title(ax,'edge displacement','FontSize',CFG.fontSizeTitle)
        end

        box(ax,'on')
        grid(ax,'on')
        hold(ax,'off')

    end

    exportFigureCm(hFig, resultsFolder, ...
                   "Contraction-" + Groups(g).Name, figSizeCm, CFG);

    close(hFig)
    toc

end

%% ============================================================
%  GROUP COMPARISON
%
%  Three panels: contraction during activation, recovery afterwards,
%  and the full time course.
%
%  Two different questions are tested and must not be confused:
%    - within group : "does this population contract at all?"
%                     -> one-sample signed-rank against zero
%    - between group: "does ACTV differ from Ctrl?"
%                     -> two-sample rank-sum
%  Only the second one is the experiment.
%% ============================================================

cmpSizeCm = [26 8];

hFig = figure('Units','centimeters', 'Color','w', ...
              'Name','Contraction - compare populations');
hFig.Position = [2 2 cmpSizeCm];

set(hFig, 'DefaultAxesFontSize', 12, 'DefaultTextFontSize', 12);

tiledlayout(hFig, 1, 3, 'Padding','tight', 'TileSpacing','loose');

Stats = struct();

% ---- panel 1: contraction ----------------------------------
ax = nexttile;
Stats.Contraction = groupBoxPanel(ax, Contractions, Groups, groupIdx, ...
        'Contraction during ACTV ($\mu$m)', CFG);

% ---- panel 2: recovery -------------------------------------
ax = nexttile;
Stats.Recovery = groupBoxPanel(ax, Recoveries, Groups, groupIdx, ...
        'Recovery after ACTV ($\mu$m)', CFG);

% ---- panel 3: mean +/- SEM of u_edge over time --------------
ax = nexttile;
hold(ax,'on')

for g = 1:numel(Groups)

    All1D = [Analyses(Groups(g).Positions).U1D_Boundary];   % T x n

    y = mean(All1D, 2, 'omitnan')';
    e = std(All1D, 0, 2, 'omitnan')' / sqrt(size(All1D,2));

    ciplot(ax, Time', y-e, y+e, Groups(g).Color);

    plot(ax, Time, y, 'Color',Groups(g).Color, 'LineWidth',2, ...
         'DisplayName',sprintf('%s (N=%d)', Groups(g).Name, size(All1D,2)));

end

% Activation window: shaded band plus dashed edges, drawn BEHIND the
% curves.

shadeActivationWindow(ax, ActTimes(1), ActTimes(2), CFG);

yline(ax, 0, 'Color',[0.5 0.5 0.5], 'LineWidth',0.5, ...
      'HandleVisibility','off');

xlim(ax, Time([1 end])')

ylabel(ax, CFG.uEdgeLabel, 'Interpreter','latex')
xlabel(ax,'Time, $t$ (h)','Interpreter','latex')

legend(ax, 'Location','northwest', 'Box','off')
grid(ax,'on')
box(ax,'on')

hold(ax,'off')

exportFigureCm(hFig, resultsFolder, "Contraction-ComparePops", cmpSizeCm, CFG);

%% ============================================================
%  MEAN SQUARED DISPLACEMENT
%
%  Top row    : TOTAL MSD. Inside the stripe this is dominated by the
%               coherent contraction and approaches tau^2 for purely
%               mechanical reasons: imposed deformation, not motility.
%  Bottom row : FLUCTUATION MSD, with the coherent 1D response
%               subtracted. The one to compare with glassy /
%               unjamming phenomenology.
%
%  Error bands are computed ACROSS POSITIONS, never across PIV nodes:
%  neighbouring nodes are closer than the correlation length, so a
%  node-wise SEM would be spuriously small.
%% ============================================================

msdSizeCm = [8*nWin, 15];

hFig = figure('Units','centimeters', 'Color','w', ...
              'Name','MSD per activation window');
hFig.Position = [2 2 msdSizeCm];

set(hFig, 'DefaultAxesFontSize', 9, 'DefaultTextFontSize', 9);

tiledlayout(hFig, 2, nWin, 'Padding','tight', 'TileSpacing','compact');

rowFields = {'raw_in','raw_far'; 'flu_in','flu_far'};
rowTitles = {'total MSD', 'fluctuation MSD'};

for r = 1:2
    for w = 1:nWin

        ax = nexttile((r-1)*nWin + w);
        hold(ax,'on')
        set(ax, 'XScale','log', 'YScale','log')

        for g = 1:numel(Groups)

            P   = Groups(g).Positions;
            tau = Analyses(P(1)).msd(w).tau_h;

            Min  = cell2mat(arrayfun(@(a) a.msd(w).(rowFields{r,1}), ...
                                     Analyses(P), 'UniformOutput',false));
            Mfar = cell2mat(arrayfun(@(a) a.msd(w).(rowFields{r,2}), ...
                                     Analyses(P), 'UniformOutput',false));

            mIn = mean(Min, 2, 'omitnan');
            eIn = std(Min, 0, 2, 'omitnan') ./ sqrt(sum(isfinite(Min),2));

            ciplot(ax, tau', (mIn-eIn)', (mIn+eIn)', Groups(g).Color);

            plot(ax, tau, mIn, '-', ...
                 'Color',Groups(g).Color, 'LineWidth',2, ...
                 'DisplayName',[char(Groups(g).Name) ' (inside)']);

            plot(ax, tau, mean(Mfar, 2, 'omitnan'), '--', ...
                 'Color',Groups(g).Color, 'LineWidth',1.2, ...
                 'DisplayName',[char(Groups(g).Name) ' (far)']);

        end

        % -------- Diffusive and ballistic guides --------
        % Anchor them to the DATA, not to ylim: on a log axis mean(ylim)
        % is dominated by the upper decade.

        yl = ylim(ax);                 % data-only limits, captured first

        tRef = [min(tau) max(tau)];
        yRef = exp(mean(log(yl)));     % geometric centre of the data range

        plot(ax, tRef, yRef*(tRef/tRef(1)).^1, ':', ...
             'Color',[0.5 0.5 0.5], 'HandleVisibility','off');
        plot(ax, tRef, yRef*(tRef/tRef(1)).^2, '-.', ...
             'Color',[0.5 0.5 0.5], 'HandleVisibility','off');

        text(ax, tRef(2), yRef*(tRef(2)/tRef(1)), ' $\tau^1$', ...
             'Interpreter','latex', 'FontSize',8, 'Color',[0.4 0.4 0.4]);
        text(ax, tRef(2), yRef*(tRef(2)/tRef(1))^2, ' $\tau^2$', ...
             'Interpreter','latex', 'FontSize',8, 'Color',[0.4 0.4 0.4]);

        % shade the region actually used for the fit
        patch('Parent',ax, ...
              'XData',CFG.msdFitLags_h([1 2 2 1]), ...
              'YData',[yl(1) yl(1) yl(2) yl(2)], ...
              'FaceColor',[0 0 0], 'FaceAlpha',0.05, ...
              'EdgeColor','none', 'HandleVisibility','off');

        ylim(ax, yl);                  % freeze: guides must not rescale
        xlim(ax, tRef);

        xlabel(ax,'Lag time, $\tau$ (h)','Interpreter','latex')

        if w == 1
            ylabel(ax,'MSD ($\mu$m$^2$)','Interpreter','latex')
            legend(ax,'Location','northwest','Box','off')
        end

        title(ax, sprintf('%s - %s', CFG.msdWindows{w,1}, rowTitles{r}))

        grid(ax,'on'); box(ax,'on'); hold(ax,'off')

    end
end

exportFigureCm(hFig, resultsFolder, "MSD-per-window", msdSizeCm, CFG);

%% ============================================================
%  MSD EXPONENTS: PER-POSITION FITS, TESTED BETWEEN GROUPS
%
%  Gamma has units of um^2 / h^alpha, so it is NOT a diffusion
%  coefficient unless alpha = 1 and must not be compared across
%  conditions with different alpha.
%% ============================================================

fprintf('\n--- MSD power law, MSD = 4 Gamma tau^alpha ---\n');
fprintf('fit range %.2f - %.2f h, weighted in log-log, per position\n', ...
        CFG.msdFitLags_h(1), CFG.msdFitLags_h(2));
fprintf('%-8s %-10s %-14s %-16s %-16s %s\n', ...
        'window','field','group','alpha (mean+-SEM)','Gamma (mean+-SEM)','p (vs other group)');

fitFields = {'raw_in','flu_in','flu_far'};
Stats.msd = struct();

for w = 1:nWin
    for q = 1:numel(fitFields)

        fn = fitFields{q};
        aG = cell(1,numel(Groups));

        for g = 1:numel(Groups)
            P     = Groups(g).Positions;
            aG{g} = arrayfun(@(a) a.msd(w).(['alpha_' fn]), Analyses(P));
        end

        if numel(Groups) == 2
            [pBetween, testName] = twoGroupTest(aG{1}, aG{2});
        else
            pBetween = NaN; testName = 'n/a';
        end

        for g = 1:numel(Groups)

            P  = Groups(g).Positions;
            al = aG{g};
            Ga = arrayfun(@(a) a.msd(w).(['Gamma_' fn]), Analyses(P));

            fprintf('%-8s %-10s %-14s %6.2f +- %-7.2f %6.3f +- %-8.3f %s\n', ...
                    CFG.msdWindows{w,1}, fn, char(Groups(g).Name), ...
                    mean(al,'omitnan'), semOf(al), ...
                    mean(Ga,'omitnan'), semOf(Ga), ...
                    ternary(g==1, sprintf('%.3g (%s)', pBetween, testName), ''));

            key = matlab.lang.makeValidName(sprintf('%s_%s_%s', ...
                        CFG.msdWindows{w,1}, fn, char(Groups(g).Name)));
            Stats.msd.(key) = struct('alpha',al(:), 'Gamma',Ga(:), ...
                                     'p_between',pBetween, 'test',testName);

        end

    end
end

%% ============================================================
%  SUMMARY TABLE, PRINT AND SAVE
%% ============================================================

groupCol = strings(nFiles,1);

for k = 1:nFiles
    if groupIdx(k) > 0
        groupCol(k) = Groups(groupIdx(k)).Name;
    else
        groupCol(k) = "unassigned";
    end
end

Summary = table((1:nFiles)', groupCol, ...
                Contractions(:), Recoveries(:), RecFractions(:), L0s(:), ...
                nanFrac(:), ...
                'VariableNames', {'Position','Group','Contraction_um', ...
                                  'Recovery_um','RecoveredFraction', ...
                                  'l0_um','NaNFraction'});

fprintf('\n--- per-position summary ---\n');
disp(Summary)

fprintf('\n--- group statistics ---\n');
printGroupStats('Contraction (um)',    Stats.Contraction, Groups);
printGroupStats('Recovery (um)',       Stats.Recovery,    Groups);

fprintf(['\nNOTE: the n above counts POSITIONS, not independent ' ...
         'experiments.\nIf several positions come from the same dish they ' ...
         'are pseudo-replicates;\nreport the number of independent ' ...
         'experiments in the figure caption.\n']);

writetable(Summary, fullfile(resultsFolder,'PerPositionSummary.csv'));

Provenance = struct('date', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
                    'matlabVersion', version, ...
                    'script', mfilename('fullpath'));

save(fullfile(resultsFolder,'AnalysisSummary.mat'), ...
     'CFG','Groups','Summary','Stats','Provenance','Time','-v7.3');

fprintf('\nSaved: %s\n', fullfile(resultsFolder,'AnalysisSummary.mat'));

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function A = CalculateStripeFlow(piv, CFG, Tref)
% Equivalent of CalculateRegionFlow for a single position.

    X  = double(piv.X);
    Y  = double(piv.Y);
    dU = double(piv.dU);
    dV = double(piv.dV);

    T = size(dU,3);

    if T ~= Tref
        error('This position has %d frames, expected %d.', T, Tref)
    end

    A.nanFraction = mean(~isfinite(dU(:)) | ~isfinite(dV(:)));

    if size(X,2) > 1 && X(1,1) == X(1,2)
        X  = X.';   Y  = Y.';
        dU = permute(dU,[2 1 3]);
        dV = permute(dV,[2 1 3]);
    end

    switch CFG.coordinateUnit
        case "px",  X = X * piv.MuPerPx;  Y = Y * piv.MuPerPx;
        case "um"   % already there
        otherwise,  error('Unknown coordinateUnit.')
    end

    if CFG.centerCoordinates
        X = X - mean(X(:),'omitnan');
        Y = Y - mean(Y(:),'omitnan');
    end

    X = X - CFG.regionCenterX_um;
    Y = Y - CFG.regionCenterY_um;

    if X(1,end) < X(1,1)
        X = fliplr(X);  Y = fliplr(Y);
        dU = flip(dU,2); dV = flip(dV,2);
    end

    if Y(end,1) < Y(1,1)
        X = flipud(X);  Y = flipud(Y);
        dU = flip(dU,1); dV = flip(dV,1);
    end

    x1D = X(1,:);
    y1D = Y(:,1);

    dx = median(diff(x1D));
    dy = median(diff(y1D));

    switch CFG.pivUnit
        case "px_per_frame", dU_um = dU * piv.MuPerPx;  dV_um = dV * piv.MuPerPx;
        case "um_per_frame", dU_um = dU;                dV_um = dV;
        case "um_per_hour",  dU_um = dU * CFG.dt_h;     dV_um = dV * CFG.dt_h;
        otherwise,           error('Unknown pivUnit.')
    end

    V_mag_um_per_h = sqrt(dU_um.^2 + dV_um.^2) / CFG.dt_h;

    if CFG.duIsCumulative
        Ucum = dU_um;
        Vcum = dV_um;
    else
        Ucum = cumsum(dU_um, 3, 'omitnan');
        Vcum = cumsum(dV_um, 3, 'omitnan');
    end

    Mcum = sqrt(Ucum.^2 + Vcum.^2);

    switch CFG.regionType

        case "Circular"
            r1D  = hypot(X, Y);
            r1D(r1D == 0) = eps;
            Rx   = X ./ r1D;
            Ry   = Y ./ r1D;
            oneD = r1D;
            projAlong = 1;

        case "Rectangular"
            if CFG.stripeIsVertical
                oneD = abs(X);
                Rx   = sign(X);
                Ry   = 0;
                projAlong = 1;
            else
                oneD = abs(Y);
                Rx   = 0;
                Ry   = sign(Y);
                projAlong = 2;
            end

        otherwise
            error('Unknown regionType.')
    end

    halfWidth = CFG.Radius1D / 2;

    inRegion   = oneD <= halfWidth;
    farRegion  = oneD >  CFG.driftRefDistance_um;
    nearRegion = ~inRegion & ~farRegion;

    bandHalf   = max(abs([dx dy]));
    inBoundary = abs(oneD - halfWidth) <= bandHalf;

    FullMask = single(inRegion);   FullMask(~inRegion)   = NaN;
    Outside  = single(~inRegion);  Outside(inRegion)     = NaN;
    BandMask = single(inBoundary); BandMask(~inBoundary) = NaN;

    U_radial = Ucum .* Rx + Vcum .* Ry;

    if projAlong == 1
        U1Dprofile = reshape(mean(Ucum, 1, 'omitnan'), size(Ucum,2), T);
        coord1D    = x1D(:);
    else
        U1Dprofile = reshape(mean(Vcum, 2, 'omitnan'), size(Vcum,1), T);
        coord1D    = y1D(:);
    end

    refMask   = abs(coord1D) > CFG.driftRefDistance_um;
    nRefNodes = nnz(refMask);

    if CFG.removeGlobalDrift && nRefNodes >= 3
        U1Dprofile = U1Dprofile - median(U1Dprofile(refMask,:), 1, 'omitnan');
    end

    if CFG.smoothFrames > 1
        U1Dprofile = movmean(U1Dprofile, CFG.smoothFrames, 2, 'omitnan');
    end

    % time derivative along dim 2; written explicitly because
    % gradient(M) with one output silently differentiates along columns
    [V1Dprofile, ~] = gradient(U1Dprofile);
    V1Dprofile = V1Dprofile / CFG.dt_h;

    % -------- Edge displacement --------
    %
    % gradient of the indicator function is +1/2 on the two nodes of the
    % left edge and -1/2 on the two nodes of the right edge, so
    %
    %   sum(u .* mask) ~ u_left - u_right
    %
    % and dividing by 2 with a minus sign gives the mean OUTWARD
    % displacement of one edge. CFG.signFactor then applies the chosen
    % convention.

    FullMask1D     = single(abs(coord1D) <= halfWidth);
    BoundaryMask1D = gradient(FullMask1D);

    nLeft  = nnz(BoundaryMask1D > 0);
    nRight = nnz(BoundaryMask1D < 0);

    if halfWidth > max(abs(coord1D))
        error(['The stripe edge (|x| = %.1f um) lies outside the PIV field ' ...
               '(|x| <= %.1f um).'], halfWidth, max(abs(coord1D)));
    end

    % The profile is INTERPOLATED at exactly +-halfWidth rather than read
    % off the two grid nodes bracketing the edge. u(x) has a kink there,
    % so a coarse PIV grid still rounds the peak off and slightly
    % underestimates the amplitude: a resolution limit, not a numerical
    % error.

    uEdgeOutward = ( interp1(coord1D, U1Dprofile,  halfWidth) ...
                   - interp1(coord1D, U1Dprofile, -halfWidth) ).' / 2;
    vEdgeOutward = ( interp1(coord1D, V1Dprofile,  halfWidth) ...
                   - interp1(coord1D, V1Dprofile, -halfWidth) ).' / 2;

    A.U1D_Boundary = CFG.signFactor * uEdgeOutward;
    A.V1D_Boundary = CFG.signFactor * vEdgeOutward;

    % change in stripe WIDTH, positive = narrowing, no factor-of-2 doubt
    A.DeltaWidth = -2 * uEdgeOutward;

    fS = CFG.activationStartFrame;
    fE = CFG.activationEndFrame;
    fX = CFG.experimentEndFrame;

    A.Contraction = A.U1D_Boundary(fE) - A.U1D_Boundary(fS);
    A.Recovery    = A.U1D_Boundary(fX) - A.U1D_Boundary(fE);

    if abs(A.Contraction) > 10*eps
        A.RecoveredFraction = -A.Recovery / A.Contraction;
    else
        A.RecoveredFraction = NaN;
    end

    % -------- Divergence of the displacement field --------
    % This is the trace of the (linearised) strain tensor, i.e. the
    % AREAL STRAIN accumulated between the two frames. Dimensionless,
    % not a rate.

    ref = CFG.divReferenceFrame;

    Udiv = Ucum(:,:,fE) - Ucum(:,:,ref);
    Vdiv = Vcum(:,:,fE) - Vcum(:,:,ref);

    divUV = divergence(X, Y, Udiv, Vdiv);

    divSigmaNodes = CFG.divSmoothing_um / mean(abs([dx dy]));
    divSigmaNodes = max(divSigmaNodes, 0.5);

    divUV = nanGaussFilt(divUV, divSigmaNodes);

    % -------- Displacement profile during activation, and l0 --------

    uProf = U1Dprofile(:,fE) - U1Dprofile(:,fS);

    [l0, l0Amp, dFold, uFold, sigmaProf] = fitDecayLength(coord1D, uProf, halfWidth, CFG);

    % -------- MSD per time window --------
    % Every PIV node is treated as a virtual tracer whose trajectory is
    % the cumulative displacement, so no cell tracking is needed.

    zones = struct('in',{inRegion}, 'near',{nearRegion}, 'far',{farRegion});

    msdC = cell(1,size(CFG.msdWindows,1));

    for w = 1:size(CFG.msdWindows,1)
        msdC{w} = stripeMSD(Ucum, Vcum, zones, CFG, CFG.msdWindows{w,2});
        msdC{w}.Name = CFG.msdWindows{w,1};
    end

    A_msd = [msdC{:}];

    % -------- Radial band profile of the velocity --------

    maxDist   = max(oneD(:));
    bandEdges = 0 : CFG.radialBandWidth_um : maxDist;
    bandCentr = bandEdges(1:end-1) + CFG.radialBandWidth_um/2;

    dU_radial = diff(U_radial, 1, 3) / CFG.dt_h;

    v_r = nan(numel(bandCentr), T);

    for b = 1:numel(bandCentr)

        m = oneD >= bandEdges(b) & oneD < bandEdges(b+1);

        if ~any(m(:))
            continue
        end

        for t = 2:T
            slice    = dU_radial(:,:,t-1);
            v_r(b,t) = mean(slice(m), 'omitnan');
        end

    end

    % -------- Outputs --------

    A.M_total    = meanXY(Mcum);
    A.M_Region   = meanXY(Mcum.*FullMask);
    A.M_Boundary = meanXY(Mcum.*BandMask);

    A.V_mag         = meanXY(V_mag_um_per_h);
    A.V_mag_Inside  = meanXY(V_mag_um_per_h.*FullMask);
    A.V_mag_Outside = meanXY(V_mag_um_per_h.*Outside);

    A.U1D_total  = meanXY(U_radial);
    A.U1D_Region = meanXY(U_radial.*FullMask);

    if strcmp(CFG.regionType, "Circular")
        A.Area_um2 = pi * halfWidth^2;
    else
        A.Area_um2 = CFG.Radius1D * range(y1D);
    end

    A.X   = X;
    A.Y   = Y;
    A.x1D = x1D;
    A.y1D = y1D;
    A.dx  = dx;
    A.dy  = dy;

    A.U_act = Ucum(:,:,fE) - Ucum(:,:,fS);
    A.V_act = Vcum(:,:,fE) - Vcum(:,:,fS);

    A.RegionMask   = FullMask;
    A.U1D          = U1Dprofile;
    A.V1D          = V1Dprofile;
    A.coord1D      = coord1D;

    A.uProfile      = uProf;      % raw u_x(x), still contains any drift
    A.uProfileFolded= uFold;      % antisymmetrised, inward-positive, drift-free
    A.dFolded       = dFold;      % distance from the stripe centre, um
    A.l0_um         = l0;
    A.l0_amp        = l0Amp;
    A.profileNoise  = sigmaProf;

    A.divUV         = divUV;
    A.divSigmaNodes = divSigmaNodes;

    A.r   = bandCentr;
    A.v_r = v_r;

    A.msd = A_msd;

    A.nLeft     = nLeft;
    A.nRight    = nRight;
    A.nRefNodes = nRefNodes;
    A.nIn       = nnz(inRegion);
    A.nNear     = nnz(nearRegion);
    A.nFar      = nnz(farRegion);

end


function M = stripeMSD(Ucum, Vcum, zones, CFG, winFrames)
% STRIPEMSD  Time-averaged MSD from the integrated PIV displacement field.
%
%   Each PIV node is a virtual tracer whose trajectory is the cumulative
%   displacement u_i(t). The MSD is averaged over reference times t0
%   within the window AND over nodes, separately in each zone:
%
%       MSD(tau) = < | u_i(t0+tau) - u_i(t0) |^2 >_{i, t0}
%
%   TWO VERSIONS are returned.
%
%   raw_* : the total MSD. Inside the stripe it is dominated by the
%           coherent contraction, a deterministic strain that drives
%           the exponent towards 2 regardless of cell motility.
%
%   flu_* : the MSD of the FLUCTUATION field. The stripe is invariant
%           along y, so the coherent response is the y-averaged
%           profile; subtracting it leaves the fluctuating motion. A
%           rigid stage drift is also uniform in y and is removed
%           automatically, which is why the explicit drift correction
%           is applied only to raw_*.
%
%   CAVEAT (Eulerian): the displacement is integrated at a FIXED grid
%   node, not following material. Valid only while the accumulated
%   displacement stays small compared with the interrogation window.
%
%   CAVEAT (collective): PIV averages over its interrogation window,
%   so this MSD underestimates the single-cell one.

    [ny, nx, T] = size(Ucum);
    N = ny * nx;

    % ---- fluctuation field: subtract the coherent y-averaged response
    %
    % Subtracting a mean estimated from the same ny samples removes a
    % fraction 1/ny of the fluctuation variance as well, exactly as in a
    % sample variance. The Bessel-like factor ny/(ny-1) puts it back.

    Ufl = Ucum - mean(Ucum, 1, 'omitnan');
    Vfl = Vcum - mean(Vcum, 1, 'omitnan');

    fluCorr = ny / max(ny-1, 1);

    U = reshape(Ucum, N, T);
    V = reshape(Vcum, N, T);
    Uf = reshape(Ufl, N, T);
    Vf = reshape(Vfl, N, T);

    % ---- Remove global (stage) drift from the RAW field --------
    % A rigid translation adds the same vector to every node and shows up
    % as a spurious tau^2 term. The reference is the far field, outside
    % the mechanical influence of the stripe.

    if CFG.msdRemoveDrift
        ref = zones.far(:);
        if nnz(ref) >= 10
            U = U - median(U(ref,:), 1, 'omitnan');
            V = V - median(V(ref,:), 1, 'omitnan');
        else
            warning('stripeMSD: only %d far-field nodes; drift NOT removed.', nnz(ref));
        end
    end

    % ---- Restrict to the requested (quasi-stationary) window --------

    f1 = max(1, winFrames(1));
    f2 = min(T, winFrames(2));

    if f2 <= f1
        error('stripeMSD: empty time window [%d %d].', winFrames(1), winFrames(2))
    end

    Tw     = f2 - f1 + 1;
    maxLag = max(1, floor(CFG.msdMaxLagFraction * Tw));

    zoneNames = {'in','near','far'};

    idx = struct();
    for z = 1:numel(zoneNames)
        idx.(zoneNames{z}) = find(zones.(zoneNames{z})(:));
    end

    M.tau_h  = (1:maxLag)' * CFG.dt_h;
    M.nPairs = zeros(maxLag,1);

    for z = 1:numel(zoneNames)
        M.(['raw_' zoneNames{z}]) = nan(maxLag,1);
        M.(['flu_' zoneNames{z}]) = nan(maxLag,1);
    end

    Uw  = U(:,  f1:f2);   Vw  = V(:,  f1:f2);
    Ufw = Uf(:, f1:f2);   Vfw = Vf(:, f1:f2);

    for Lag = 1:maxLag

        d2raw = (Uw(:, 1+Lag:end) - Uw(:, 1:end-Lag)).^2 ...
              + (Vw(:, 1+Lag:end) - Vw(:, 1:end-Lag)).^2;

        d2flu = (Ufw(:, 1+Lag:end) - Ufw(:, 1:end-Lag)).^2 ...
              + (Vfw(:, 1+Lag:end) - Vfw(:, 1:end-Lag)).^2;

        for z = 1:numel(zoneNames)
            k = idx.(zoneNames{z});
            if isempty(k), continue, end
            tr = d2raw(k,:);
            tf = d2flu(k,:);
            M.(['raw_' zoneNames{z}])(Lag) = mean(tr(:), 'omitnan');
            M.(['flu_' zoneNames{z}])(Lag) = fluCorr * mean(tf(:), 'omitnan');
        end

        M.nPairs(Lag) = size(d2raw,2);

    end

    % ---- power-law fits, per position -------------------------

    fitFields = {'raw_in','raw_near','raw_far','flu_in','flu_near','flu_far'};

    for q = 1:numel(fitFields)
        fn = fitFields{q};
        [al, Ga, ep] = fitMSDPowerLaw(M.tau_h, M.(fn), ...
                                      CFG.msdFitLags_h, CFG.msdFitOffset);
        M.(['alpha_' fn]) = al;
        M.(['Gamma_' fn]) = Ga;
        M.(['eps_'   fn]) = ep;
    end

    M.Name = '';

end


function [alpha, Gamma, eps_um] = fitMSDPowerLaw(tau, msd, fitRange, useOffset)
% Fit MSD = 4 Gamma tau^alpha  (optionally + 2 eps^2).
%
% The log-log fit is WEIGHTED by d(log tau): tau is linearly spaced, so
% an unweighted fit is dominated by the crowded long-lag decade, which
% is also the noisiest part of the curve.
%
% Gamma has units um^2 / h^alpha. It is a diffusion coefficient only if
% alpha = 1; do not compare Gamma across conditions with different alpha.

    alpha = NaN; Gamma = NaN; eps_um = NaN;

    tau = tau(:); msd = msd(:);

    sel = tau >= fitRange(1) & tau <= fitRange(2) & isfinite(msd) & msd > 0;

    if nnz(sel) < 3
        return
    end

    t = tau(sel);
    m = msd(sel);

    lt = log10(t);
    lm = log10(m);

    w = gradient(lt);
    w = w / sum(w);

    pf = lscov([lt, ones(numel(lt),1)], lm, w);

    alpha  = pf(1);
    Gamma  = 10^pf(2) / 4;
    eps_um = 0;

    if useOffset
        % MSD = 4 G tau^a + offset, offset = 2 eps^2
        q0  = [log10(max(Gamma,1e-12)), alpha, log10(max(min(m)/2, 1e-6))];
        obj = @(q) sum( w .* ( log10(4*10^q(1)*t.^q(2) + 10^q(3)) - lm ).^2 );
        opt = optimset('Display','off','MaxFunEvals',4000,'MaxIter',4000);
        q   = fminsearch(obj, q0, opt);

        Gamma  = 10^q(1);
        alpha  = q(2);
        eps_um = sqrt(10^q(3) / 2);
    end

end


function [l0, amp, dGrid, uFold, sigmaProf] = fitDecayLength(coord1D, uProf, halfWidth, CFG)
% Exponential decay length of the displacement outside the stripe.
%
%   mag(d) = amp * exp( -(d - halfWidth) / l0 ),   d = |x| > halfWidth
%
% The profile is FOLDED about x = 0:
%
%   antisymmetric part  uOut(d) = ( u(+d) - u(-d) ) / 2   -> the signal
%   symmetric part      uSym(d) = ( u(+d) + u(-d) ) / 2   -> drift + noise
%
% The stripe response is antisymmetric by construction, so the SYMMETRIC
% part contains no signal and gives a data-driven estimate of the noise
% on the profile. A uniform stage drift is symmetric and is therefore
% removed exactly by the folding, which is why no drift correction is
% needed here.
%
% The fit is refined in LINEAR space. A pure log-linear fit is biased:
% log of a noisy positive quantity has a negative bias that grows as
% the tail approaches the noise floor, which makes the decay look
% faster and UNDERESTIMATES l0 (about -15% in synthetic tests).

    l0 = NaN; amp = NaN; dGrid = []; uFold = []; sigmaProf = NaN;

    coord1D = coord1D(:);
    uProf   = uProf(:);

    good = isfinite(coord1D) & isfinite(uProf);

    if nnz(good) < 6
        return
    end

    dMax = min(max(coord1D(good)), -min(coord1D(good)));

    if ~isempty(CFG.l0FitMaxDist_um)
        dMax = min(dMax, CFG.l0FitMaxDist_um);
    end

    if dMax <= halfWidth + 2
        return
    end

    dGrid = linspace(0, dMax, 80).';

    uPlus  = interp1(coord1D(good), uProf(good),  dGrid, 'linear', NaN);
    uMinus = interp1(coord1D(good), uProf(good), -dGrid, 'linear', NaN);

    uOut = (uPlus - uMinus) / 2;      % antisymmetric: the signal
    uSym = (uPlus + uMinus) / 2;      % symmetric: drift + noise

    % inward-positive, i.e. the same convention as everything else
    uFold = CFG.signFactor * uOut;

    % noise level: scatter of the symmetric part about its own mean
    sig = uSym(isfinite(uSym));
    if numel(sig) >= 4
        sigmaProf = std(sig - mean(sig));
    else
        sigmaProf = 0;
    end

    floorLevel = max(CFG.profileNoiseFloor_um, 3*sigmaProf);

    % -------- select the fit range --------

    outside = dGrid > halfWidth;

    nHead = find(outside, 5, 'first');
    sgn   = sign(median(uFold(nHead), 'omitnan'));

    if ~isfinite(sgn) || sgn == 0
        return
    end

    mag = sgn * uFold;

    ok = outside & isfinite(mag) & mag > floorLevel;

    % keep only the leading run: once the profile drops into the noise,
    % later points are sign-random and would drag the fit
    idxOut   = find(outside);
    firstBad = find(~ok(idxOut), 1, 'first');

    if ~isempty(firstBad)
        ok(idxOut(firstBad:end)) = false;
    end

    if nnz(ok) < 4
        return
    end

    d = dGrid(ok) - halfWidth;
    m = mag(ok);

    % -------- initial guess: log-linear --------

    p = polyfit(d, log(m), 1);

    if p(1) >= 0
        return
    end

    l0  = -1 / p(1);
    amp = exp(p(2));

    % -------- refinement: unbiased least squares in linear space -------

    q0  = [log(amp), log(l0)];
    obj = @(q) sum( ( exp(q(1)) * exp(-d/exp(q(2))) - m ).^2 );
    opt = optimset('Display','off','MaxFunEvals',2000,'MaxIter',2000);
    q   = fminsearch(obj, q0, opt);

    ampR = exp(q(1));
    l0R  = exp(q(2));

    if isfinite(l0R) && l0R > 0 && l0R < 10*range(dGrid)
        l0  = l0R;
        amp = ampR;
    end

end


function m = meanXY(A3)
% Mean over the two spatial dimensions of a [ny x nx x T] array,
% returned as a column vector of length T. Written without mean(...,[1 2])
% so it also runs on older MATLAB and on Octave.

    [ny, nx, T] = size(A3);
    m = mean(reshape(A3, ny*nx, T), 1, 'omitnan').';

end


function Z = nanGaussFilt(Zin, sigmaNodes)
% Gaussian smoothing that does not let a single NaN poison the whole
% kernel support, and does not require the Image Processing Toolbox.
%
% Normalised convolution: the kernel is applied to the zero-filled data
% and to the validity mask, and the two are divided. This also handles
% the array borders correctly.

    r = max(1, ceil(3*sigmaNodes));

    [gx, gy] = meshgrid(-r:r, -r:r);

    K = exp(-(gx.^2 + gy.^2) / (2*sigmaNodes^2));
    K = K / sum(K(:));

    valid = double(isfinite(Zin));

    Z0 = Zin;
    Z0(~isfinite(Z0)) = 0;

    num = conv2(Z0,    K, 'same');
    den = conv2(valid, K, 'same');

    Z = num ./ den;
    Z(den < 0.05) = NaN;

end


function S = groupBoxPanel(ax, values, Groups, groupIdx, yLabelLatex, CFG)
% Box plot + jittered points + both statistical tests.
%
% The box shows median and inter-quartile range only; whiskers are
% suppressed because every individual point is drawn on top. Say so in
% the figure caption.
%
% ---------------- ANNOTATION LAYOUT ----------------
%
% All vertical positions are fractions of the DATA range (the axis
% limits before any headroom is added), so they stay put when the y
% scale changes. The order matters:
%
%   1. read the data limits
%   2. decide where every annotation goes
%   3. set the final ylim, with enough headroom for all of them
%
% Tune the gaps with CFG.stat* if the numbers are long or the panel
% is short.

    if nargin < 6, CFG = struct(); end

    CFG = withDefault(CFG, 'statStarGap',      0.05);  % star above each box
    CFG = withDefault(CFG, 'statBracketGap',   0.18);  % bracket above data
    CFG = withDefault(CFG, 'statTickHeight',   0.025); % bracket end ticks
    CFG = withDefault(CFG, 'statTextGap',      0.03);  % text above bracket
    CFG = withDefault(CFG, 'statHeadroom',     0.18);  % blank space on top
    CFG = withDefault(CFG, 'fontSizeStar',     14);
    CFG = withDefault(CFG, 'fontSizeStat',     12);

    hold(ax,'on')

    valid  = groupIdx > 0;
    labels = string({Groups.Name});

    boxplot(ax, values(valid), groupIdx(valid), ...
            'Widths',0.4, 'Whisker',0, 'Symbol','', ...
            'Labels',cellstr(labels));

    for g = 1:numel(Groups)
        y = values(Groups(g).Positions);
        x = g + 0.07*randn(size(y));
        scatter(ax, x, y, 22, 'filled', ...
                'MarkerFaceColor',Groups(g).Color, ...
                'MarkerEdgeColor','k', 'MarkerFaceAlpha',0.8);
    end

    yline(ax, 0, 'Color',[0.5 0.5 0.5], 'LineWidth',0.5);

    ylabel(ax, yLabelLatex, 'Interpreter','latex')
    xlabel(ax, 'Population', 'Interpreter','latex')

    S = struct();
    S.groupNames = labels;
    S.values     = cell(1,numel(Groups));
    S.p_within   = nan(1,numel(Groups));
    S.test_within  = 'n/a';
    S.p_between    = NaN;
    S.test_between = 'n/a';

    % -------- 1) tests, no drawing yet --------

    for g = 1:numel(Groups)

        y = values(Groups(g).Positions);
        y = y(isfinite(y));

        S.values{g} = y(:);

        if numel(y) >= 3
            [S.p_within(g), S.test_within] = oneSampleTest(y);
        end

    end

    doBetween = numel(Groups) == 2 && ...
                numel(S.values{1}) >= 3 && numel(S.values{2}) >= 3;

    if doBetween
        [S.p_between, S.test_between] = twoGroupTest(S.values{1}, S.values{2});
    end

    % -------- 2) fix the reference frame ONCE --------

    ylData = ylim(ax);            % limits set by the data alone
    r      = diff(ylData);

    if r <= 0 || ~isfinite(r)
        r = 1;
    end

    yTopData = ylData(2);

    % -------- 3) draw, anchored to that frame --------

    for g = 1:numel(Groups)

        if ~isfinite(S.p_within(g))
            continue
        end

        yG = max(S.values{g});    % just above this group's own points,
                                  % not at a fixed height, so the star
                                  % never lands on a data marker

        text(ax, g, yG + CFG.statStarGap*r, ...
             significanceLabel(S.p_within(g)), ...
             'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', ...
             'FontSize',CFG.fontSizeStar, 'Color',[0.4 0.4 0.4]);

    end

    yTopAnnot = yTopData;

    if doBetween

        yBar  = yTopData + CFG.statBracketGap*r;
        yTick = yBar - CFG.statTickHeight*r;

        plot(ax, [1 1 2 2], [yTick yBar yBar yTick], ...
             'k-', 'LineWidth',0.8, 'HandleVisibility','off');

        % kept short on purpose: a string like '****  p = 3.234e-05' is
        % wider than the bracket itself in a narrow panel
        text(ax, 1.5, yBar + CFG.statTextGap*r, ...
             sprintf('%s  p = %.2g', ...
                     significanceLabel(S.p_between), S.p_between), ...
             'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', ...
             'FontSize',CFG.fontSizeStat);

        yTopAnnot = yBar;

    end

    % -------- 4) headroom last --------

    ylim(ax, [ylData(1), yTopAnnot + CFG.statHeadroom*r]);

    box(ax,'on')
    hold(ax,'off')

end


function CFG = withDefault(CFG, field, value)

    if ~isfield(CFG, field) || isempty(CFG.(field))
        CFG.(field) = value;
    end

end


function [factor, label, note] = signConvention(contractionPositive)
% Single source of truth for the sign convention, so a figure and its
% axis label can never disagree.

    if contractionPositive
        factor = -1;
        label  = '$u_{\mathrm{edge}}$ ($\mu$m), inward $>0$';
        note   = 'contraction positive (edges move inward)';
    else
        factor = +1;
        label  = '$u_{\mathrm{edge}}$ ($\mu$m), outward $>0$';
        note   = 'outward positive (contraction negative)';
    end

end


function [p, name] = oneSampleTest(y)
% Non-parametric where possible: n ~ 12 does not justify assuming
% normality, and a single outlying position dominates a t-test.

    y = y(isfinite(y));

    if exist('signrank','file') == 2
        p    = signrank(y);
        name = 'signed-rank vs 0';
    elseif exist('ttest','file') == 2
        [~, p] = ttest(y);
        name   = 'one-sample t-test vs 0';
    else
        p    = NaN;
        name = 'no test available';
    end

end


function [p, name] = twoGroupTest(a, b)

    a = a(isfinite(a));
    b = b(isfinite(b));

    if numel(a) < 3 || numel(b) < 3
        p = NaN; name = 'n too small';
        return
    end

    if exist('ranksum','file') == 2
        p    = ranksum(a, b);
        name = 'rank-sum';
    elseif exist('ttest2','file') == 2
        [~, p] = ttest2(a, b, 'Vartype','unequal');
        name   = 'Welch t-test';
    else
        p    = NaN;
        name = 'no test available';
    end

end


function printGroupStats(label, S, Groups)

    fprintf('%s\n', label);

    for g = 1:numel(Groups)
        y = S.values{g};
        fprintf('   %-14s N=%2d   median %8.3f   mean %8.3f +- %.3f (SEM)   p(vs 0) = %.3g\n', ...
                char(Groups(g).Name), numel(y), median(y,'omitnan'), ...
                mean(y,'omitnan'), semOf(y), S.p_within(g));
    end

    fprintf('   between groups: p = %.3g (%s)\n\n', S.p_between, S.test_between);

end


function s = semOf(y)

    y = y(isfinite(y));

    if numel(y) < 2
        s = NaN;
    else
        s = std(y) / sqrt(numel(y));
    end

end


function out = ternary(cond, a, b)

    if cond
        out = a;
    else
        out = b;
    end

end


function drawScaleArrow(ax, arrowLen_um, labelStr, CFG)
% Reference arrow for a fixed-scale quiver, drawn in data units in the
% bottom-right corner.

    xl = xlim(ax);
    yl = ylim(ax);

    x0 = xl(2) - 0.06*diff(xl) - arrowLen_um;
    y0 = yl(1) + 0.10*diff(yl);

    quiver(ax, x0, y0, arrowLen_um, 0, 0, ...
           'Color','k', 'LineWidth',1, 'MaxHeadSize',1, ...
           'HandleVisibility','off');

    text(ax, x0, y0 - 0.05*diff(yl), labelStr, ...
         'FontSize',CFG.fontSizeAxes, 'VerticalAlignment','top');

end


function setPanelAspect(ax, CFG)
% Let the panel fill its tile. axis image only on request.

    if CFG.preserveAspect
        axis(ax,'image')
    end

end


function cb = tileColorbar(ax, CFG)
% Colorbar anchored to the tile. Never write to cb.Position: that
% switches the colorbar to manual placement and tiledlayout then moves
% the axes out from under it.

    cb = colorbar(ax);
    cb.FontSize  = CFG.fontSizeAxes;
    cb.LineWidth = CFG.lineWidthAxes;

end


function t = niceTicks(v)
% Round tick values spanning the data, at most about 4 intervals.

    lo = min(v(:));
    hi = max(v(:));

    if ~isfinite(lo) || ~isfinite(hi) || lo == hi
        t = [0 1];
        return
    end

    step = 10^floor(log10((hi-lo)/2));
    cand = step * [1 2 5 10];
    step = cand(find((hi-lo)./cand <= 4, 1));

    t = ceil(lo/step)*step : step : floor(hi/step)*step;

    if numel(t) < 2
        t = [lo hi];
    end

end


function plotRegion(ax, CFG, colorRGBA)

    halfWidth = CFG.Radius1D / 2;

    if strcmp(CFG.regionType, "Circular")
        th = linspace(0, 2*pi, 200);
        plot(ax, halfWidth*cos(th), halfWidth*sin(th), ...
             'Color',colorRGBA, 'LineWidth',1.2, 'HandleVisibility','off');
        return
    end

    if CFG.stripeIsVertical
        xline(ax, -halfWidth, 'Color',colorRGBA, 'LineWidth',1.2);
        xline(ax,  halfWidth, 'Color',colorRGBA, 'LineWidth',1.2);
    else
        yline(ax, -halfWidth, 'Color',colorRGBA, 'LineWidth',1.2);
        yline(ax,  halfWidth, 'Color',colorRGBA, 'LineWidth',1.2);
    end

end


function shadeActivationWindow(ax, tOn, tOff, CFG)
% Shade the activation window and mark its edges with dashed lines.
%
% xregion spans the full y range automatically, stays behind the data
% and follows any later change of the y limits, which a patch built
% from the current ylim does not: if the limits are touched afterwards
% the patch no longer reaches the top of the axes.

    try
        hReg = xregion(ax, tOn, tOff, ...
            'FaceColor', CFG.actvShadeColor, ...
            'FaceAlpha', CFG.actvShadeAlpha, ...
            'EdgeColor', 'none');
        set(hReg, 'HandleVisibility', 'off');
    catch
        yl = ylim(ax);
        hReg = patch('Parent',ax, ...
            'XData',[tOn tOff tOff tOn], ...
            'YData',[yl(1) yl(1) yl(2) yl(2)], ...
            'FaceColor', CFG.actvShadeColor, ...
            'FaceAlpha', CFG.actvShadeAlpha, ...
            'EdgeColor', 'none', ...
            'HandleVisibility','off');
        uistack(hReg, 'bottom');
        ylim(ax, yl);
    end

    xline(ax, tOn,  'k--', 'LineWidth', 1.3, 'HandleVisibility','off');
    xline(ax, tOff, 'k--', 'LineWidth', 1.3, 'HandleVisibility','off');

end


function cmap = neutralWhiteMap()

    n = 256;

    green  = [0.00 0.35 0.15];
    white  = [1.00 1.00 1.00];
    purple = [0.55 0.25 0.60];

    nHalf = round(n/2);

    c1 = [linspace(green(1),white(1),nHalf)', ...
          linspace(green(2),white(2),nHalf)', ...
          linspace(green(3),white(3),nHalf)'];

    c2 = [linspace(white(1),purple(1),n-nHalf)', ...
          linspace(white(2),purple(2),n-nHalf)', ...
          linspace(white(3),purple(3),n-nHalf)'];

    cmap = [c1; c2];

end


function s = significanceLabel(p)

    if ~isfinite(p)
        s = 'n.s.';
    elseif p < 1e-4
        s = '****';
    elseif p < 1e-3
        s = '***';
    elseif p < 1e-2
        s = '**';
    elseif p < 0.05
        s = '*';
    else
        s = 'n.s.';
    end

end


function ciplot(ax, x, lower, upper, colorRGB)

    x     = x(:).';
    lower = lower(:).';
    upper = upper(:).';

    good = isfinite(lower) & isfinite(upper);

    x     = x(good);
    lower = lower(good);
    upper = upper(good);

    if isempty(x)
        return
    end

    patch('Parent',ax, ...
          'XData',[x fliplr(x)], ...
          'YData',[lower fliplr(upper)], ...
          'FaceColor',colorRGB, 'FaceAlpha',0.25, ...
          'EdgeColor','none', 'HandleVisibility','off');

end


function lim = paddedLimits(y)

    y = y(isfinite(y));

    if isempty(y)
        lim = [-1 1];
        return
    end

    lo  = min(y);
    hi  = max(y);
    pad = 0.1 * (hi - lo);

    if pad == 0
        pad = 1;
    end

    lim = [lo-pad, hi+pad];

end


function exportFigureCm(hFig, folder, name, sizeCm, CFG)
% Export at the REQUESTED size, not the on-screen size.
%
% exportgraphics ignores PaperSize / PaperPosition and writes the
% on-screen size, and MATLAB clamps figure Position to the display.
% print() honours the paper properties, so the requested size is
% passed in explicitly.

    name = char(name);

    set(hFig, 'PaperUnits','centimeters', ...
              'PaperSize', sizeCm, ...
              'PaperPositionMode','manual', ...
              'PaperPosition',[0 0 sizeCm]);

    print(hFig, fullfile(folder,[name '.png']), ...
          '-dpng', sprintf('-r%d', CFG.exportResolution));

    if CFG.exportPDF
        if ~verLessThan('matlab','9.11')      % R2021b+
            print(hFig, fullfile(folder,[name '.pdf']), '-dpdf', '-vector');
        else
            print(hFig, fullfile(folder,[name '.pdf']), '-dpdf', '-painters');
        end
    end

end