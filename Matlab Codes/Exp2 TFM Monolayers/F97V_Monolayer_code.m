
%% ============================================================
%  GLOBAL STYLE
%% ============================================================
try; reset(groot); catch; end
clearvars; close all; clc

set(groot, 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
           'defaultTextColor','k',  'defaultColorbarColor','k', ...
           'defaultAxesFontWeight','bold', 'defaultTextFontWeight','bold', ...
           'defaultTextInterpreter','latex', ...
           'defaultAxesTickLabelInterpreter','latex', ...
           'defaultLegendInterpreter','latex', ...
           'defaultAxesFontSize',12, 'defaultTextFontSize',12)

set(groot, 'defaultAxesFontSize',  12)
set(groot, 'defaultTextFontSize',  12)
set(groot, 'defaultLegendFontSize', 12)


%% ============================================================
%  USER PARAMETERS  ← all configurable inputs are here
%% ============================================================

% ---- Data files ----
MBI_file_name           = 'F97V-Monolayer-18kPa-Day4-MBI.mat';
TFM_file_name           = 'T.mat';
Displacements_file_name = 'D.mat';

% ---- Positions ----
GoodPositions = 1;

% ---- Activation stripe (µm) ----
stripeYMin = -100;
stripeYMax =  100;

% ---- Activation colour code ----
colorOFF = [0 0 0];              % control / light OFF
colorON  = [0.00 0.40 0.95];     % light ON

% ---- Analysis switches ----
makeVideos          = false;
makeIndividualPlots = false;
makeAveragePlot     = true;
makeProfileVideos   = true;
doFits              = true;

% ---- Profile video options ----
showProfileFig    = true;
saveProfileVideos = true;
profileFrameRate  = 15;

% ---- Font sizes: profile videos ----
profileAxesFontSize  = 25;   % tick labels
profileLabelFontSize = 25;   % xlabel / ylabel
profileTitleFontSize = 25;   % panel titles
profileTimeFontSize  = 25;   % hh:mm:ss global title
profileFigSize       = [1200 610];   % [width height] in px (enlarge with the font)

% ---- Strain energy ----
showStrainEnergy = true;   % set to true when Displ data is available

% ---- Smoothing ----
useSmoothing = false;
smoothWindow = 5;

% ---- Fitting ----
fitTarget            = 'inside';   % 'inside' | 'outside'
controlFitDuration_h = 0.5;
relFitDuration_h     = 2.0;

% ---- Font sizes: average plot + fits ----
avgAxesFontSize   = 25;   % tick labels
avgLabelFontSize  = 25;   % xlabel / ylabel
avgLegendFontSize = 21;   % legend (tau_act, tau_rel, ...)

% ---- Fit visualisation (does NOT affect fitting windows) ----
fitPlotExtension_h   = 0.0;
actFitPlotStart_h    = 0.0;
relFitPlotDuration_h = 2.0;
relFitStart_h        = 0.0;
nFitPlotPoints       = 200;




%% ============================================================
%  FOLDERS
%% ============================================================
dataFolder    = 'Data';
resultsFolder = 'Results';
auxFolder     = 'Auxiliar';

figuresFolder        = fullfile(resultsFolder, 'Figures');
tractionVideoFolder  = fullfile(resultsFolder, 'Traction Videos');

for d = {resultsFolder, auxFolder, figuresFolder, tractionVideoFolder}
    if ~exist(d{1}, 'dir'); mkdir(d{1}); end
end


%% ============================================================
%  DATA LOADING AND TIME AXIS
%% ============================================================
load(fullfile(dataFolder, MBI_file_name));
load(fullfile(dataFolder, TFM_file_name));
load(fullfile(dataFolder, Displacements_file_name));

time_h       = hours(MBI.Time - MBI.Time(1));
time_h       = time_h(:);
total_time_h = time_h(end);

ctrl_start_h = 0.5;
actv_h       = 1.0;
ctrl_end_h   = total_time_h - ctrl_start_h - actv_h; 

actv_pos = GoodPositions;


%% ============================================================
%  ACTIVATION MASKS
%% ============================================================
Masks = cell(1, max(GoodPositions));

for p = GoodPositions
    Tr       = T(p);
    Masks{p} = Tr.Y >= stripeYMin & Tr.Y <= stripeYMax;
end

% Optional mask check
checkMask = true;
if checkMask
    pCheck  = GoodPositions(1);
    Tr      = T(pCheck);

    figMask = figure('Color','w');
    ax      = axes(figMask);

    imagesc(ax, Tr.X(1,:), Tr.Y(:,1), Masks{pCheck})
    axis(ax, 'equal'); axis(ax, 'tight')

    ax.FontSize = 20;

    cb          = colorbar(ax);
    cb.FontSize = 16;


    clim(ax, [0 1])      % asegura que la escala de color va de 0 a 1
    cb.Ticks = [0 1];    % solo muestra 0 y 1


    xlabel(ax, '$x \, (\mu\mathrm{m})$')
    ylabel(ax, '$y \, (\mu\mathrm{m})$')

    exportgraphics(figMask, fullfile(auxFolder, 'Mask.png'), 'Resolution', 300)
end

%% ============================================================
%  TRACTION VIDEOS (Tx, Ty, |T|  +  optional Local Energy)
%% ============================================================
if makeVideos

    cmap_bwr = [linspace(0,1,128)' linspace(0.5,1,128)' ones(128,1); ...
                ones(128,1) linspace(1,0,128)' linspace(1,0.25,128)'];

    for p = GoodPositions

        Tr      = T(p);
        nFrames = size(Tr.U, 3);
        assert(numel(time_h) == nFrames, ...
            'time_h and traction frames mismatch for position %d.', p)

        if showStrainEnergy
            D       = D(p);
            nCols   = 4;
            figW    = 1400;
        else
            nCols   = 3;
            figW    = 1100;
        end

        % ---- Video writer ----
        v = VideoWriter(fullfile(tractionVideoFolder, sprintf('Tractions_P%d.mp4',p)), 'MPEG-4');
        v.FrameRate = 10;
        open(v)

        % ---- Figure and layout ----
        fig = figure('Units','pixels','Position',[100 100 figW 400], ...
                     'Resize','off','Color','w');

        tl = tiledlayout(1, nCols, 'Padding','compact', 'TileSpacing','compact');
        tl.OuterPosition = [0, 0, 1, 0.92];

        xVals   = Tr.X(1,:);
        yVals   = Tr.Y(:,1);
        xLimits = Tr.X(1,[2,end-1]);
        yLimits = Tr.Y([2,end-1],1);

        % ---- First frame data ----
        Tx1 = Tr.U(:,:,1);
        Ty1 = Tr.V(:,:,1);
        Tm1 = hypot(Tx1, Ty1);

        % ---- Tx ----
        ax1 = nexttile;
        hTx = imagesc(xVals, yVals, Tx1, [-100 100]);
        colormap(ax1, cmap_bwr)
        axis(ax1,'equal'); axis(ax1,'tight')
        xlim(ax1, xLimits); ylim(ax1, yLimits)
        xlabel(ax1, '$x \, (\mu\mathrm{m})$'); ylabel(ax1, '$y \, (\mu\mathrm{m})$')
        title(ax1, 'x-Tractions')
        cb1 = colorbar(ax1); cb1.Label.Interpreter = 'latex';
        cb1.Label.String = 'Tractions, $T_x$ (Pa)';
        hold(ax1,'on')

        % ---- Ty ----
        ax2 = nexttile;
        hTy = imagesc(xVals, yVals, Ty1, [-100 100]);
        colormap(ax2, cmap_bwr)
        axis(ax2,'equal'); axis(ax2,'tight')
        xlim(ax2, xLimits); ylim(ax2, yLimits)
        xlabel(ax2, '$x \, (\mu\mathrm{m})$')
        title(ax2, 'y-Tractions')
        cb2 = colorbar(ax2); cb2.Label.Interpreter = 'latex';
        cb2.Label.String = 'Tractions, $T_y$ (Pa)';
        hold(ax2,'on')

        % ---- |T| ----
        ax3 = nexttile;
        hTm = imagesc(xVals, yVals, Tm1, [0 140]);
        colormap(ax3, sky)
        axis(ax3,'equal'); axis(ax3,'tight')
        xlim(ax3, xLimits); ylim(ax3, yLimits)
        xlabel(ax3, '$x \, (\mu\mathrm{m})$')
        title(ax3, 'Traction magnitude')
        cb3 = colorbar(ax3); cb3.Label.Interpreter = 'latex';
        cb3.Label.String = 'Tractions, $|{\bf T}|$ (Pa)';
        hold(ax3,'on')

        % ---- Local energy (optional) ----
        if showStrainEnergy
            Dx1 = D.U(:,:,1);
            Dy1 = D.V(:,:,1);
            E1  = 0.5 * (Tx1 .* Dx1 + Ty1 .* Dy1);

            ax4 = nexttile;
            hE  = imagesc(xVals, yVals, E1, [0 30]);
            colormap(ax4, sky)
            axis(ax4,'equal'); axis(ax4,'tight')
            xlim(ax4, xLimits); ylim(ax4, yLimits)
            xlabel(ax4, '$x \, (\mu\mathrm{m})$')
            title(ax4, 'Local Energy')
            cb4 = colorbar(ax4); cb4.Label.Interpreter = 'latex';
            cb4.Label.String = 'Local Energy, $E$ ($\mathrm{Pa} \cdot \mu\mathrm{m}$)';
            hold(ax4,'on')
        end

        % ---- Mask rectangle ----
        rectPos  = [min(Tr.X(:)), stripeYMin, max(Tr.X(:))-min(Tr.X(:)), stripeYMax-stripeYMin];
        axList   = [ax1, ax2, ax3];
        if showStrainEnergy; axList = [axList, ax4]; end
        hMask    = gobjects(1, nCols);
        for k = 1:nCols
            hMask(k) = rectangle(axList(k), ...
                'Position',  rectPos, ...
                'FaceColor', 'none', ...
                'EdgeColor', 'k', ...
                'LineWidth',  1.5);
        end

        % ---- Time loop ----
        frameSize = [];

        for tIdx = 1:nFrames

            edgeColor = colorOFF;
            if ismember(p, actv_pos) && ...
               time_h(tIdx) >= ctrl_start_h && time_h(tIdx) <= ctrl_start_h + actv_h
                edgeColor = colorON;
            end

            Tx = Tr.U(:,:,tIdx);
            Ty = Tr.V(:,:,tIdx);

            set(hTx, 'CData', Tx)
            set(hTy, 'CData', Ty)
            set(hTm, 'CData', hypot(Tx, Ty))
            set(hMask, 'EdgeColor', edgeColor)

            if showStrainEnergy
                Dx = D.U(:,:,tIdx);
                Dy = D.V(:,:,tIdx);
                set(hE, 'CData', 0.5*(Tx.*Dx + Ty.*Dy))
            end

            % Global title hh:mm:ss
            total_sec = round(time_h(tIdx) * 3600);
            title(tl, sprintf('%02d:%02d:%02d', ...
                floor(total_sec/3600), ...
                floor(mod(total_sec,3600)/60), ...
                mod(total_sec,60)), ...
                'Interpreter','latex')

            drawnow limitrate

            frame = getframe(fig);
            if isempty(frameSize)
                frameSize = size(frame.cdata);
            elseif any(size(frame.cdata) ~= frameSize)
                frame.cdata = imresize(frame.cdata, frameSize(1:2));
            end
            writeVideo(v, frame)

        end

        close(v); close(fig)
    end
end


%% ============================================================
%  TRACTION MAGNITUDE: INSIDE / OUTSIDE MASK
%% ============================================================
nPos    = numel(GoodPositions);
nFrames = size(T(GoodPositions(1)).U, 3);
assert(numel(time_h) == nFrames, 'time_h and traction frames mismatch.')

Tmag_in_all  = nan(nFrames, nPos);
Tmag_out_all = nan(nFrames, nPos);

for i = 1:nPos
    p       = GoodPositions(i);
    Tr      = T(p);
    maskIn  = Masks{p};
    maskOut = ~maskIn;
    assert(isequal(size(maskIn), size(Tr.U(:,:,1))), ...
        'Mask / traction size mismatch for position %d.', p)

    for tIdx = 1:nFrames
        Tmag = sqrt(Tr.U(:,:,tIdx).^2 + Tr.V(:,:,tIdx).^2);
        Tmag_in_all(tIdx,i)  = mean(Tmag(maskIn),  'omitnan');
        Tmag_out_all(tIdx,i) = mean(Tmag(maskOut), 'omitnan');
    end
end

save(fullfile(resultsFolder,'TractionMagnitude_Metrics.mat'), ...
    'time_h','GoodPositions','actv_pos', ...
    'Tmag_in_all','Tmag_out_all', ...
    'ctrl_start_h','actv_h','stripeYMin','stripeYMax')


%% ============================================================
%  ACTIVATION FACTOR: <|T|> DURING vs. BEFORE ACTIVATION
%% ============================================================

% ---- Window definition ----
baselineSkip_h = 0.0;    % skip the first frames (drift settling)
plateauSkip_h  = 0.0;    % skip the transient right after light ON

tOn_r  = ctrl_start_h;
tOff_r = ctrl_start_h + actv_h;

baselineIdx = time_h >= baselineSkip_h & time_h < tOn_r;
plateauIdx  = time_h >= tOn_r + plateauSkip_h & time_h <= tOff_r;

assert(nnz(baselineIdx) > 0, 'Empty baseline window.')
assert(nnz(plateauIdx)  > 0, 'Empty activation window.')

fprintf('\n')
fprintf('Baseline window   : %.3f - %.3f h  (%d frames)\n', ...
    time_h(find(baselineIdx,1)), time_h(find(baselineIdx,1,'last')), nnz(baselineIdx));
fprintf('Activation window : %.3f - %.3f h  (%d frames)\n', ...
    time_h(find(plateauIdx,1)),  time_h(find(plateauIdx,1,'last')),  nnz(plateauIdx));

% ---- Per-position means ----
baseIn  = nan(nPos,1);   actIn  = nan(nPos,1);   peakIn = nan(nPos,1);
baseOut = nan(nPos,1);   actOut = nan(nPos,1);

for i = 1:nPos
    baseIn(i)  = mean(Tmag_in_all(baselineIdx, i),  'omitnan');
    actIn(i)   = mean(Tmag_in_all(plateauIdx,  i),  'omitnan');
    peakIn(i)  =  max(Tmag_in_all(plateauIdx,  i), [], 'omitnan');

    baseOut(i) = mean(Tmag_out_all(baselineIdx, i), 'omitnan');
    actOut(i)  = mean(Tmag_out_all(plateauIdx,  i), 'omitnan');
end

ratioIn     = actIn  ./ baseIn;
ratioOut    = actOut ./ baseOut;
ratioPeakIn = peakIn ./ baseIn;

% ---- Summary table ----
ratioTable = table( ...
    GoodPositions(:), ...
    baseIn, actIn, ratioIn, ratioPeakIn, ...
    baseOut, actOut, ratioOut, ...
    'VariableNames', {'Position', ...
    'Base_in_Pa','Act_in_Pa','Ratio_in','RatioPeak_in', ...
    'Base_out_Pa','Act_out_Pa','Ratio_out'});

fprintf('\n')
disp(ratioTable)

% ---- Pooled statistics ----
N_r = nnz(isfinite(ratioIn));

ratioIn_mean = mean(ratioIn, 'omitnan');
ratioIn_std  = std(ratioIn, 0, 'omitnan');
ratioIn_sem  = ratioIn_std / sqrt(N_r);

fprintf('\n')
fprintf('=========== ACTIVATION FACTOR (inside stripe) ===========\n')
fprintf('Ratio = <|T|>_activation / <|T|>_baseline\n\n')
fprintf('Sustained : %.3f\n', ratioIn_mean);
fprintf('Peak      : %.3f\n', mean(ratioPeakIn,'omitnan'));
if N_r > 1
    fprintf('SD        : %.3f\n', ratioIn_std);
    fprintf('SEM       : %.3f   (N = %d)\n', ratioIn_sem, N_r);
    fprintf('Range     : [%.3f , %.3f]\n', min(ratioIn), max(ratioIn));
else
    fprintf('(single position: no across-position dispersion available)\n');
end
fprintf('Outside   : %.3f   (internal control, expected near 1)\n', ...
    mean(ratioOut,'omitnan'));
fprintf('=========================================================\n')

% ---- One-sample test (only meaningful with several positions) ----
if N_r >= 3 && exist('ttest','file') == 2
    [~, pRatio] = ttest(ratioIn, 1, 'Tail', 'right');
    fprintf('\nOne-sample t-test (H0: ratio = 1, H1: ratio > 1): p = %.4g\n', pRatio);
end

% ---- Save ----
save(fullfile(resultsFolder,'ActivationFactor.mat'), ...
    'ratioTable','ratioIn','ratioOut','ratioPeakIn', ...
    'baseIn','actIn','peakIn','baseOut','actOut', ...
    'baselineIdx','plateauIdx','baselineSkip_h','plateauSkip_h')

writetable(ratioTable, fullfile(resultsFolder,'ActivationFactor.csv'))



%% ============================================================
%  INDIVIDUAL POSITION PLOTS
%% ============================================================
if makeIndividualPlots

    for i = 1:nPos
        p    = GoodPositions(i);
        yIn  = Tmag_in_all(:,i);
        yOut = Tmag_out_all(:,i);

        yMin    = min([yIn; yOut], [], 'omitnan');
        yMax    = max([yIn; yOut], [], 'omitnan');
        padding = max(0.1*(yMax-yMin), 1);
        yLimits = [yMin-padding, yMax+padding];

        figInd = figure('Color','w', 'Position',[100 100 700 430]);
        hold on

        patch([ctrl_start_h, ctrl_start_h+actv_h, ctrl_start_h+actv_h, ctrl_start_h], ...
              [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
              [0.85 0.85 1],'EdgeColor','none','FaceAlpha',0.5,'HandleVisibility','off')

        plot(time_h, yIn,  'LineWidth',2, 'DisplayName','Inside mask')
        plot(time_h, yOut, 'LineWidth',2, 'DisplayName','Outside mask')

        for tEdge = [ctrl_start_h, ctrl_start_h+actv_h]
            plot([tEdge tEdge], yLimits, '--k', 'LineWidth',1.5, 'HandleVisibility','off')
        end

        ylim(yLimits); xlim([0 total_time_h])
        xlabel('$t \, (\mathrm{h})$'); ylabel('$\langle |{\bf T}| \rangle \, (\mathrm{Pa})$')
        title(sprintf('Traction magnitude inside vs. outside mask, P%d', p))
        legend('show','Location','best'); grid on; box on

        print(figInd, fullfile(figuresFolder, ...
            sprintf('TractionMagnitude_InsideOutside_P%d.png',p)), '-dpng','-r300')
    end
end


%% ============================================================
%  AVERAGE ACROSS POSITIONS: MEAN ± SEM + SMOOTHING
%% ============================================================
Tmag_in_mean  = mean(Tmag_in_all,  2, 'omitnan');
Tmag_out_mean = mean(Tmag_out_all, 2, 'omitnan');

nIn  = sum(~isnan(Tmag_in_all),  2);
nOut = sum(~isnan(Tmag_out_all), 2);

Tmag_in_sem  = std(Tmag_in_all,  0, 2, 'omitnan') ./ sqrt(nIn);
Tmag_out_sem = std(Tmag_out_all, 0, 2, 'omitnan') ./ sqrt(nOut);
Tmag_in_sem(nIn==0) = nan;  Tmag_out_sem(nOut==0) = nan;

if nPos == 1
    Tmag_in_sem(:) = 0;  Tmag_out_sem(:) = 0;
end

hasSmoothData = exist('smoothdata','file')==2 || exist('smoothdata','builtin')==5;

if useSmoothing && hasSmoothData
    Tmag_in_plot      = smoothdata(Tmag_in_mean,  'movmean', smoothWindow);
    Tmag_out_plot     = smoothdata(Tmag_out_mean, 'movmean', smoothWindow);
    Tmag_in_sem_plot  = smoothdata(Tmag_in_sem,   'movmean', smoothWindow);
    Tmag_out_sem_plot = smoothdata(Tmag_out_sem,  'movmean', smoothWindow);
else
    Tmag_in_plot      = Tmag_in_mean;
    Tmag_out_plot     = Tmag_out_mean;
    Tmag_in_sem_plot  = Tmag_in_sem;
    Tmag_out_sem_plot = Tmag_out_sem;
    if useSmoothing; warning('smoothdata not found – plotting raw curves.'); end
end

% Select curve for fitting
switch fitTarget
    case 'inside',  yFitRaw = Tmag_in_mean(:);  fitLabel = 'Inside average';
    case 'outside', yFitRaw = Tmag_out_mean(:); fitLabel = 'Outside average';
    otherwise, error('fitTarget must be ''inside'' or ''outside''.')
end
t = time_h(:);


%% ============================================================
%  AVERAGE PLOT: MEAN ± SEM + EXPONENTIAL FITS
%% ============================================================
if makeAveragePlot

    figAvg = figure('Color','w', 'Position',[100 100 850 670]);

    tl  = tiledlayout(1, 1, 'Padding','compact', 'TileSpacing','compact');
    ax  = nexttile;
    hold(ax, 'on')

    % ---- Font size (only this plot) ----
    ax.FontSize = 30;

    C = lines(2);

    allY    = [Tmag_in_plot+Tmag_in_sem_plot; Tmag_in_plot-Tmag_in_sem_plot; ...
               Tmag_out_plot+Tmag_out_sem_plot; Tmag_out_plot-Tmag_out_sem_plot];
    yMin    = min(allY,[],'omitnan');
    yMax    = max(allY,[],'omitnan');
    padding = max(0.1*(yMax-yMin), 1);
    yLimits = [yMin-padding, yMax+padding];

    tOn  = ctrl_start_h;
    tOff = ctrl_start_h + actv_h;

    % Activation shading
    patch(ax, [tOn tOff tOff tOn], [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
          [0.85 0.85 1],'EdgeColor','none','FaceAlpha',0.5,'HandleVisibility','off')

    % SEM bands
    fill(ax, [t; flipud(t)], ...
         [Tmag_in_plot+Tmag_in_sem_plot; flipud(Tmag_in_plot-Tmag_in_sem_plot)], ...
         C(1,:),'EdgeColor','none','FaceAlpha',0.25,'HandleVisibility','off')
    fill(ax, [t; flipud(t)], ...
         [Tmag_out_plot+Tmag_out_sem_plot; flipud(Tmag_out_plot-Tmag_out_sem_plot)], ...
         C(2,:),'EdgeColor','none','FaceAlpha',0.25,'HandleVisibility','off')

    % Mean curves
    plot(ax, t, Tmag_in_plot,  'Color',C(1,:), 'LineWidth',2.5, 'DisplayName','Inside actv. region')
    plot(ax, t, Tmag_out_plot, 'Color',C(2,:), 'LineWidth',2.5, 'DisplayName','Outside actv. region')

    % Activation boundaries
    for tEdge = [tOn, tOff]
        xline(ax, tEdge, '--k', 'LineWidth',1.5, 'HandleVisibility','off')
    end

    % ----------------------------------------------------------
    %  EXPONENTIAL FITS
    % ----------------------------------------------------------
    fitAct = []; fitRel = []; gofAct = []; gofRel = [];
    y0_fixed = nan; tPeak = nan;

    % ---- Helper: standard error of a fitted coefficient from its 95% CI ----
    if exist('tinv','file') == 2
        tcrit = @(dfe) tinv(0.975, max(dfe,1));   % 95% CI -> 1 sigma
    else
        tcrit = @(dfe) 1.96;                      % no Statistics Toolbox
    end
    seFromCI = @(ci,dfe) abs(diff(ci)) / (2*tcrit(dfe));

    if doFits && exist('fit','file') == 2

        yPeakSignal = yFitRaw;
        if useSmoothing && hasSmoothData
            yPeakSignal = smoothdata(yFitRaw, 'movmean', smoothWindow);
        end

        % ---- Activation fit ----
        y0ControlStart_h = 0.0;
        y0ControlEnd_h   = tOn;

        idxY0    = t >= y0ControlStart_h & t < y0ControlEnd_h;
        y0_fixed = median(yFitRaw(idxY0), 'omitnan');
        if isnan(y0_fixed); y0_fixed = mean(yFitRaw(idxY0),'omitnan'); end
        if isnan(y0_fixed)
            warning('Could not estimate y0 – using first finite value.')
            y0_fixed = yFitRaw(find(isfinite(yFitRaw),1));
        end

        idxAct = t >= tOn & t <= tOff;
        tAct_w = t(idxAct);
        yAct_w = yPeakSignal(idxAct);
        valid  = isfinite(tAct_w) & isfinite(yAct_w);
        tAct_w = tAct_w(valid);  yAct_w = yAct_w(valid);

        if numel(yAct_w) >= 4
            [~, iPeak] = max(yAct_w);
            tPeak = tAct_w(iPeak);

            idxFit = t >= y0ControlStart_h & t <= tPeak;
            tFit0  = t(idxFit) - tOn;
            yFit   = yFitRaw(idxFit);
            valid  = isfinite(tFit0) & isfinite(yFit);
            tFit0  = tFit0(valid);  yFit = yFit(valid);

            if numel(yFit) >= 4 && max(tFit0) > 0
                A0 = max(max(yFit) - y0_fixed, 1);

                ftAct = fittype('y0_fixed + A*(1-exp(-max(x,0)/tau))', ...
                    'independent','x','coefficients',{'A','tau'},'problem','y0_fixed');
                opts = fitoptions('Method','NonlinearLeastSquares', ...
                    'StartPoint',[A0, 0.1], 'Lower',[0, 0.001], 'Upper',[Inf, max(tFit0)]);
                [fitAct, gofAct] = fit(tFit0, yFit, ftAct, opts, 'problem', y0_fixed);

                tPlot = linspace(max(0,actFitPlotStart_h), ...
                                 min(total_time_h, tPeak+fitPlotExtension_h), nFitPlotPoints)';
                yPlot = y0_fixed + fitAct.A .* (1 - exp(-max(tPlot-tOn,0) ./ fitAct.tau));

                % ---- tau_act +- sigma ----
                ciAct  = confint(fitAct, 0.95);
                iTau   = strcmp(coeffnames(fitAct), 'tau');
                tauAct = fitAct.tau;
                sAct   = seFromCI(ciAct(:,iTau), gofAct.dfe);
                if isfinite(sAct)
                    labAct = sprintf('$\\tau_{\\mathrm{act}} = %.2f \\pm %.2f$ h', tauAct, sAct);
                else
                    labAct = sprintf('$\\tau_{\\mathrm{act}} = %.2f$ h', tauAct);
                    warning('Activation fit: CI not finite (parameter may be at a bound).')
                end

                plot(ax, tPlot, yPlot, 'b--', 'LineWidth',2.5, 'DisplayName',labAct)
            else
                warning('Insufficient points for activation fit.')
            end
        else
            warning('Insufficient points to detect peak.')
        end

        % ---- Relaxation fit ----
        idxRel = t >= tOff+relFitStart_h & t <= tOff+relFitStart_h+relFitDuration_h;
        tRel0  = t(idxRel) - (tOff + relFitStart_h);
        yRel   = yFitRaw(idxRel);
        valid  = isfinite(tRel0) & isfinite(yRel);
        tRel0  = tRel0(valid);  yRel = yRel(valid);

        if numel(yRel) >= 4
            ftRel = fittype('yinf + A*exp(-x/tau)', ...
                'independent','x','coefficients',{'yinf','A','tau'});
            opts = fitoptions('Method','NonlinearLeastSquares', ...
                'StartPoint',[yRel(end), max(yRel(1)-yRel(end),1), 0.5], ...
                'Lower',[0, 0, 0.001], 'Upper',[Inf, Inf, relFitDuration_h]);
            [fitRel, gofRel] = fit(tRel0, yRel, ftRel, opts);

            tPlot0 = linspace(0, min(relFitPlotDuration_h+fitPlotExtension_h, ...
                              total_time_h-tOff), nFitPlotPoints)';

            % ---- tau_rel +- sigma ----
            ciRel  = confint(fitRel, 0.95);
            iTau   = strcmp(coeffnames(fitRel), 'tau');
            tauRel = fitRel.tau;
            sRel   = seFromCI(ciRel(:,iTau), gofRel.dfe);
            if isfinite(sRel)
                labRel = sprintf('$\\tau_{\\mathrm{rel}} = %.2f \\pm %.2f$ h', tauRel, sRel);
            else
                labRel = sprintf('$\\tau_{\\mathrm{rel}} = %.2f$ h', tauRel);
                warning('Relaxation fit: CI not finite (parameter may be at a bound).')
            end

            plot(ax, tOff+tPlot0, fitRel(tPlot0), 'g--', 'LineWidth',2.5, 'DisplayName',labRel)
        else
            warning('Insufficient points for relaxation fit.')
        end

    elseif doFits
        warning('Curve Fitting Toolbox not found – skipping fits.')
    end

    % ----------------------------------------------------------
    %  FIT SUMMARY (Command Window)
    % ----------------------------------------------------------
    if doFits
        fprintf('\n===== EXPONENTIAL FIT SUMMARY (%s) =====\n', fitLabel);

        if ~isempty(fitAct)
            ciA = confint(fitAct, 0.95);
            iA  = strcmp(coeffnames(fitAct), 'A');
            iT  = strcmp(coeffnames(fitAct), 'tau');
            fprintf('--- Activation:  y = y0 + A*(1 - exp(-t/tau)) ---\n');
            fprintf('  y0    = %8.3f Pa   (fixed, median of pre-activation)\n', y0_fixed);
            fprintf('  A     = %8.3f +- %.3f Pa\n', ...
                fitAct.A,   seFromCI(ciA(:,iA), gofAct.dfe));
            fprintf('  tau   = %8.3f +- %.3f h   (= %.1f min)\n', ...
                fitAct.tau, seFromCI(ciA(:,iT), gofAct.dfe), 60*fitAct.tau);
            fprintf('  R^2   = %8.4f   adj R^2 = %.4f   RMSE = %.3f   dfe = %d\n', ...
                gofAct.rsquare, gofAct.adjrsquare, gofAct.rmse, gofAct.dfe);
            fprintf('  peak at t = %.2f h\n', tPeak);
        else
            fprintf('--- Activation:  no fit available ---\n');
        end

        if ~isempty(fitRel)
            ciR = confint(fitRel, 0.95);
            iY  = strcmp(coeffnames(fitRel), 'yinf');
            iA  = strcmp(coeffnames(fitRel), 'A');
            iT  = strcmp(coeffnames(fitRel), 'tau');
            fprintf('--- Relaxation:  y = yinf + A*exp(-t/tau) ---\n');
            fprintf('  yinf  = %8.3f +- %.3f Pa\n', ...
                fitRel.yinf, seFromCI(ciR(:,iY), gofRel.dfe));
            fprintf('  A     = %8.3f +- %.3f Pa\n', ...
                fitRel.A,    seFromCI(ciR(:,iA), gofRel.dfe));
            fprintf('  tau   = %8.3f +- %.3f h   (= %.1f min)\n', ...
                fitRel.tau,  seFromCI(ciR(:,iT), gofRel.dfe), 60*fitRel.tau);
            fprintf('  R^2   = %8.4f   adj R^2 = %.4f   RMSE = %.3f   dfe = %d\n', ...
                gofRel.rsquare, gofRel.adjrsquare, gofRel.rmse, gofRel.dfe);
        else
            fprintf('--- Relaxation:  no fit available ---\n');
        end

        if ~isempty(fitAct) && ~isempty(fitRel)
            fprintf('--- Ratio: tau_rel / tau_act = %.2f ---\n', fitRel.tau/fitAct.tau);
        end
        fprintf('==========================================\n\n');
    end

    % ---- Formatting and save ----
    ylim(ax, yLimits); xlim(ax, [0 total_time_h])
    xlabel(ax, '$t \, (\mathrm{h})$')
    ylabel(ax, '$\langle |{\bf T}| \rangle \, (\mathrm{Pa})$')

    lgd = legend(ax, 'show');
    lgd.Interpreter = 'latex';
    lgd.NumColumns  = 2;
    lgd.FontSize    = 20;
    lgd.Box         = 'off';
    lgd.Layout.Tile = 'south';    % outside the axes, below

    grid(ax, 'on'); box(ax, 'on')

    exportgraphics(figAvg, fullfile(figuresFolder, ...
        sprintf('Average_TractionMagnitude_SEM_FitOverAverage_%s.png', fitTarget)), ...
        'Resolution', 300)
    savefig(figAvg, fullfile(figuresFolder, ...
        sprintf('Average_TractionMagnitude_SEM_FitOverAverage_%s.fig', fitTarget)))
end

%% ============================================================
%  PROFILE VIDEOS (1-D spatial profiles along Y)
%% ============================================================
if makeProfileVideos

    profileVideoFolder = fullfile(resultsFolder, 'ProfileVideos');
    if ~exist(profileVideoFolder,'dir'); mkdir(profileVideoFolder); end

    for p = GoodPositions

        Tr      = T(p);
        nFrames = size(Tr.U, 3);
        assert(numel(time_h) == nFrames, ...
            'time_h and traction frames mismatch for position %d.', p)

        y_um = Tr.Y(:,1);

        % ---- Precompute profiles ----
        TmagProfile  = nan(numel(y_um), nFrames);
        TyProfile    = nan(numel(y_um), nFrames);

        for tIdx = 1:nFrames
            Tx_t = Tr.U(:,:,tIdx);
            Ty_t = Tr.V(:,:,tIdx);
            TmagProfile(:,tIdx) = mean(sqrt(Tx_t.^2 + Ty_t.^2), 2, 'omitnan');
            TyProfile(:,tIdx)   = mean(Ty_t, 2, 'omitnan');
        end

        % ---- Video writer ----
        if saveProfileVideos
            v = VideoWriter(fullfile(profileVideoFolder, sprintf('Profiles_Y_P%d.mp4',p)), 'MPEG-4');
            v.FrameRate = profileFrameRate;
            open(v)
        end

        % ---- Figure visibility ----
        if showProfileFig
            figVisibility = 'on';
        else
            figVisibility = 'off';
        end

        % ---- Figure and layout ----
        figProfile = figure('Units','pixels', ...
                            'Position',[100 100 profileFigSize(1) profileFigSize(2)], ...
                            'Resize','off','Color','w','Visible',figVisibility);

        tl = tiledlayout(1, 2, 'Padding','compact', 'TileSpacing','loose');
        tl.OuterPosition = [0, 0, 1, 0.92];

        stripeVerts = [stripeYMin stripeYMax stripeYMax stripeYMin];
        

        % ---- Panel 1: |T| ----
        ax1 = nexttile;
        hold(ax1,'on')
        patch(stripeVerts, [0 0 45 45], ...
              [0.8 0.8 0.8],'EdgeColor','none','FaceAlpha',0.4,'HandleVisibility','off')
        hTmag = plot(ax1, y_um, TmagProfile(:,1), 'LineWidth',2.5, 'Color','k');
        ax1.FontSize = profileAxesFontSize;
        ax1.LabelFontSizeMultiplier = 1;  ax1.TitleFontSizeMultiplier = 1;
        xlabel(ax1, '$y \, (\mu\mathrm{m})$',  'FontSize', profileLabelFontSize)
        ylabel(ax1, 'Mean $|{\bf T}|$ (Pa)',   'FontSize', profileLabelFontSize)
        title(ax1, '$|{\bf T}|$ profile',      'FontSize', profileTitleFontSize)
        xlim(ax1, [min(y_um) max(y_um)]); ylim(ax1, [0 45])
        grid(ax1,'on'); box(ax1,'on')

        % ---- Panel 2: Ty ----
        ax2 = nexttile;
        hold(ax2,'on')
        patch(stripeVerts, [-25 -25 25 25], ...
              [0.8 0.8 0.8],'EdgeColor','none','FaceAlpha',0.4,'HandleVisibility','off')
        hTy = plot(ax2, y_um, TyProfile(:,1), 'LineWidth',2.5, 'Color','k');
        ax2.FontSize = profileAxesFontSize;
        ax2.LabelFontSizeMultiplier = 1;  ax2.TitleFontSizeMultiplier = 1;
        xlabel(ax2, '$y \, (\mu\mathrm{m})$', 'FontSize', profileLabelFontSize)
        ylabel(ax2, 'Mean $T_y$ (Pa)',        'FontSize', profileLabelFontSize)
        title(ax2, '$T_y$ profile',           'FontSize', profileTitleFontSize)
        xlim(ax2, [min(y_um) max(y_um)]); ylim(ax2, [-25 25])
        grid(ax2,'on'); box(ax2,'on')

        % ---- Time loop ----
        frameSize = [];

        for tIdx = 1:nFrames

            set(hTmag, 'YData', TmagProfile(:,tIdx))
            set(hTy,   'YData', TyProfile(:,tIdx))

            edgeColor = colorOFF;
            if ismember(p, actv_pos) && ...
               time_h(tIdx) >= ctrl_start_h && time_h(tIdx) <= ctrl_start_h + actv_h
                edgeColor = colorON;
            end
            set(ax1, 'XColor',edgeColor, 'YColor',edgeColor)
            set(ax2, 'XColor',edgeColor, 'YColor',edgeColor)

            for axP = [ax1 ax2]
                axP.XLabel.Color = edgeColor;
                axP.YLabel.Color = edgeColor;
                axP.Title.Color  = edgeColor;
            end

            % Global title hh:mm:ss
            total_sec = round(time_h(tIdx) * 3600);
            title(tl, sprintf('%02d:%02d:%02d', ...
                floor(total_sec/3600), ...
                floor(mod(total_sec,3600)/60), ...
                mod(total_sec,60)), ...
                'Interpreter','latex', 'FontSize', profileTimeFontSize, ...
                'Color', edgeColor)

            drawnow limitrate

            if saveProfileVideos
                frame = getframe(figProfile);
                if isempty(frameSize)
                    frameSize = size(frame.cdata);
                elseif any(size(frame.cdata) ~= frameSize)
                    frame.cdata = imresize(frame.cdata, frameSize(1:2));
                end
                writeVideo(v, frame)
            end

        end

        if saveProfileVideos; close(v); end
        if ~showProfileFig;   close(figProfile); end

    end
end