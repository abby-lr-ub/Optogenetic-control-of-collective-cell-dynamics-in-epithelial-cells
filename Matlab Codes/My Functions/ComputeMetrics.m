
% -------- FUNCTION CREATION --------

function Metrics = ComputeMetrics( ...
    TFM, Displ, Masks, GoodPositions, time_h, actv_pos, ctrl_pos)

% -------- METRICS STRUCTURE --------

Metrics = struct();

% -------- BASIC FEATURES -------- (from data files)

Metrics.GoodPositions = GoodPositions;
Metrics.time_h = time_h;
Metrics.pixelSize_um = TFM{1}.Settings.TFM_PixelSize_Mu;
Metrics.pixelArea_um2 = Metrics.pixelSize_um^2;


% -------- INITIALIZATION --------

nPositions = max(GoodPositions);
nFrames = numel(time_h);

Metrics.meanTx_in  = nan(nPositions, nFrames);
Metrics.meanTx_out = nan(nPositions, nFrames);

Metrics.meanTy_in  = nan(nPositions, nFrames);
Metrics.meanTy_out = nan(nPositions, nFrames);

Metrics.meanTm_in  = nan(nPositions, nFrames);
Metrics.meanTm_out = nan(nPositions, nFrames);

Metrics.meanE_in   = nan(nPositions, nFrames);
Metrics.meanE_out  = nan(nPositions, nFrames);

Metrics.intE_in    = nan(nPositions, nFrames); % aJ
Metrics.intE_out   = nan(nPositions, nFrames); % aJ

Metrics.intE_in_pJ    = nan(nPositions, nFrames); % pJ
Metrics.intE_out_pJ   = nan(nPositions, nFrames); % pJ

Metrics.stdTx_in   = nan(nPositions, nFrames);
Metrics.stdTx_out  = nan(nPositions, nFrames);

Metrics.stdTy_in   = nan(nPositions, nFrames);
Metrics.stdTy_out  = nan(nPositions, nFrames);

Metrics.stdTm_in   = nan(nPositions, nFrames);
Metrics.stdTm_out  = nan(nPositions, nFrames);

Metrics.stdE_in    = nan(nPositions, nFrames);
Metrics.stdE_out   = nan(nPositions, nFrames);

Metrics.maskArea_px  = nan(nPositions, 1);
Metrics.maskArea_um2 = nan(nPositions, 1);

% -------- COMPUTATION --------

for p = GoodPositions

    T = TFM{p};
    D = Displ{p};

    maskIn  = Masks{p};
    maskOut = ~maskIn;

    Metrics.maskArea_px(p)  = sum(maskIn(:));
    Metrics.maskArea_um2(p) = Metrics.maskArea_px(p) * Metrics.pixelArea_um2;

    for t = 1:nFrames

        Tx = T.Tx(:,:,t);
        Ty = T.Ty(:,:,t);

        Dx = D.Dx(:,:,t);
        Dy = D.Dy(:,:,t);

        Tm = hypot(Tx, Ty);

        E = 0.5 * (Tx .* Dx + Ty .* Dy);

        Tx_in = Tx(maskIn);
        Tx_out = Tx(maskOut);

        Ty_in = Ty(maskIn);
        Ty_out = Ty(maskOut);

        Tm_in  = Tm(maskIn);
        Tm_out = Tm(maskOut);

        E_in   = E(maskIn);
        E_out  = E(maskOut);

        % -------- SAVING --------

        Metrics.meanTx_in(p,t)  = mean(abs(Tx_in),  "omitnan");         % absolute value
        Metrics.meanTx_out(p,t) = mean(abs(Tx_out), "omitnan");         % absolute value

        Metrics.stdTx_in(p,t)   = std(abs(Tx_in),  "omitnan");          % absolute value
        Metrics.stdTx_out(p,t)  = std(abs(Tx_out), "omitnan");          % absolute value

        Metrics.meanTy_in(p,t)  = mean(abs(Ty_in),  "omitnan");         % absolute value
        Metrics.meanTy_out(p,t) = mean(abs(Ty_out), "omitnan");         % absolute value

        Metrics.stdTy_in(p,t)   = std(abs(Ty_in),  "omitnan");          % absolute value
        Metrics.stdTy_out(p,t)  = std(abs(Ty_out), "omitnan");          % absolute value

        Metrics.meanTm_in(p,t)  = mean(Tm_in,  "omitnan");
        Metrics.meanTm_out(p,t) = mean(Tm_out, "omitnan");

        Metrics.stdTm_in(p,t)   = std(Tm_in,  "omitnan");
        Metrics.stdTm_out(p,t)  = std(Tm_out, "omitnan");

        Metrics.meanE_in(p,t)   = mean(E_in,  "omitnan");
        Metrics.meanE_out(p,t)  = mean(E_out, "omitnan");

        Metrics.stdE_in(p,t)    = std(E_in,  "omitnan");
        Metrics.stdE_out(p,t)   = std(E_out, "omitnan");

        Metrics.intE_in(p,t)  = sum(E_in,  "omitnan") * Metrics.pixelArea_um2;
        Metrics.intE_out(p,t) = sum(E_out, "omitnan") * Metrics.pixelArea_um2;

        Metrics.intE_in_pJ(p,t) = ...       % pJ
            Metrics.intE_in(p,t) * 1e-6;

        Metrics.intE_out_pJ(p,t) = ...      % pJ
            Metrics.intE_out(p,t) * 1e-6;

    end

end


% -------- AVERAGE OVER ACTIVATED AND CONTROL POSITIONS --------

N_actv = numel(actv_pos);
N_ctrl = numel(ctrl_pos);

% -------- Tx --------

Metrics.avg.Tx_in_mean = mean(Metrics.meanTx_in(actv_pos,:), 1, "omitnan");
Metrics.avg.Tx_in_std  = std( Metrics.meanTx_in(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Tx_in_sem  = Metrics.avg.Tx_in_std / sqrt(N_actv);

Metrics.avg.Tx_out_mean = mean(Metrics.meanTx_out(actv_pos,:), 1, "omitnan");
Metrics.avg.Tx_out_std  = std( Metrics.meanTx_out(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Tx_out_sem  = Metrics.avg.Tx_out_std / sqrt(N_actv);

Metrics.avg.Tx_in_ctrl_mean = mean(Metrics.meanTx_in(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Tx_in_ctrl_std  = std( Metrics.meanTx_in(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Tx_in_ctrl_sem  = Metrics.avg.Tx_in_ctrl_std / sqrt(N_ctrl);

Metrics.avg.Tx_out_ctrl_mean = mean(Metrics.meanTx_out(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Tx_out_ctrl_std  = std( Metrics.meanTx_out(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Tx_out_ctrl_sem  = Metrics.avg.Tx_out_ctrl_std / sqrt(N_ctrl);


% -------- Ty --------

Metrics.avg.Ty_in_mean = mean(Metrics.meanTy_in(actv_pos,:), 1, "omitnan");
Metrics.avg.Ty_in_std  = std( Metrics.meanTy_in(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Ty_in_sem  = Metrics.avg.Ty_in_std / sqrt(N_actv);

Metrics.avg.Ty_out_mean = mean(Metrics.meanTy_out(actv_pos,:), 1, "omitnan");
Metrics.avg.Ty_out_std  = std( Metrics.meanTy_out(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Ty_out_sem  = Metrics.avg.Ty_out_std / sqrt(N_actv);

Metrics.avg.Ty_in_ctrl_mean = mean(Metrics.meanTy_in(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Ty_in_ctrl_std  = std( Metrics.meanTy_in(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Ty_in_ctrl_sem  = Metrics.avg.Ty_in_ctrl_std / sqrt(N_ctrl);

Metrics.avg.Ty_out_ctrl_mean = mean(Metrics.meanTy_out(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Ty_out_ctrl_std  = std( Metrics.meanTy_out(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Ty_out_ctrl_sem  = Metrics.avg.Ty_out_ctrl_std / sqrt(N_ctrl);


% -------- Tm --------

Metrics.avg.Tm_in_mean = mean(Metrics.meanTm_in(actv_pos,:), 1, "omitnan");
Metrics.avg.Tm_in_std  = std( Metrics.meanTm_in(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Tm_in_sem  = Metrics.avg.Tm_in_std / sqrt(N_actv);

Metrics.avg.Tm_out_mean = mean(Metrics.meanTm_out(actv_pos,:), 1, "omitnan");
Metrics.avg.Tm_out_std  = std( Metrics.meanTm_out(actv_pos,:), 0, 1, "omitnan");
Metrics.avg.Tm_out_sem  = Metrics.avg.Tm_out_std / sqrt(N_actv);

Metrics.avg.Tm_in_ctrl_mean = mean(Metrics.meanTm_in(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Tm_in_ctrl_std  = std( Metrics.meanTm_in(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Tm_in_ctrl_sem  = Metrics.avg.Tm_in_ctrl_std / sqrt(N_ctrl);

Metrics.avg.Tm_out_ctrl_mean = mean(Metrics.meanTm_out(ctrl_pos,:), 1, "omitnan");
Metrics.avg.Tm_out_ctrl_std  = std( Metrics.meanTm_out(ctrl_pos,:), 0, 1, "omitnan");
Metrics.avg.Tm_out_ctrl_sem  = Metrics.avg.Tm_out_ctrl_std / sqrt(N_ctrl);

end