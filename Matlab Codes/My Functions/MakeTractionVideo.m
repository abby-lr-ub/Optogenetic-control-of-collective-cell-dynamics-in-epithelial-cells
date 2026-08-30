
% -------- FUNCTION CREATION --------

function MakeTractionVideo( ...
    T, D, Mask, MBI_Time, p, actv_pos, ...
    ctrl_start_h, actv_h, resultsFolder, ...
    showVideos, saveVideos)

% --- Exit if nothing is required ---

if ~showVideos && ~saveVideos
    return
end

% --- Video creation ---

if saveVideos

    videoName = fullfile(resultsFolder, "Tractions_P" + p + ".mp4");

    v = VideoWriter(videoName, "MPEG-4");
    v.FrameRate = 25;

    open(v)

end

% --- Figure visibility ---

if showVideos
    figVisibility = "on";
else
    figVisibility = "off";
end

% --- Figure creation ---

fig = figure( ...
    "Units", "pixels", ...
    "Position", [100 100 1400 400], ...
    "Resize", "off", ...
    "Color", "w", ...
    "Visible", figVisibility);

tl = tiledlayout(1,4, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");

% --- Colormaps ---

cmap_bwr = [ ...
    linspace(0,1,128)' linspace(0.5,1,128)' ones(128,1); ...
    ones(128,1) linspace(1,0,128)' linspace(1,0.25,128)' ...
];

% --- Coordinates and limits ---

xVals = T.X(1,:);
yVals = T.Y(:,1);

xLimits = T.X(1,[2,end-1]);
yLimits = T.Y([2,end-1],1);

% --- First frame ---

Tx1 = T.Tx(:,:,1);
Ty1 = T.Ty(:,:,1);

Dx1 = D.Dx(:,:,1);
Dy1 = D.Dy(:,:,1);

Tm1 = hypot(Tx1, Ty1);
E1  = 0.5 * (Tx1 .* Dx1 + Ty1 .* Dy1);

% --- Tx plot ---

ax1 = nexttile;
hTx = imagesc(xVals, yVals, Tx1, [-100 100]);

colormap(ax1, cmap_bwr)

axis(ax1, "equal")
axis(ax1, "tight")

xlim(ax1, xLimits)
ylim(ax1, yLimits)

xlabel(ax1, "$x \, (\mu\mathrm{m})$")
ylabel(ax1, "$y \, (\mu\mathrm{m})$")

title(ax1, "x-Tractions")

cb1 = colorbar(ax1);
cb1.Label.Interpreter = "latex";
cb1.Label.String = "Tractions, $T_x$ (Pa)";

hold(ax1, "on")

% --- Ty plot ---

ax2 = nexttile;
hTy = imagesc(xVals, yVals, Ty1, [-100 100]);

colormap(ax2, cmap_bwr)

axis(ax2, "equal")
axis(ax2, "tight")

xlim(ax2, xLimits)
ylim(ax2, yLimits)

xlabel(ax2, "$x \, (\mu\mathrm{m})$")

title(ax2, "y-Tractions")

cb2 = colorbar(ax2);
cb2.Label.Interpreter = "latex";
cb2.Label.String = "Tractions, $T_y$ (Pa)";

hold(ax2, "on")

% --- Traction magnitude plot ---

ax3 = nexttile;
hTm = imagesc(xVals, yVals, Tm1, [0 150]);

colormap(ax3, sky)

axis(ax3, "equal")
axis(ax3, "tight")

xlim(ax3, xLimits)
ylim(ax3, yLimits)

xlabel(ax3, "$x \, (\mu\mathrm{m})$")

title(ax3, "Traction magnitude")

cb3 = colorbar(ax3);
cb3.Label.Interpreter = "latex";
cb3.Label.String = "Tractions, $|{\bf T}|$ (Pa)";

hold(ax3, "on")

% --- Local energy plot ---

ax4 = nexttile;
hE = imagesc(xVals, yVals, E1, [0 30]);

colormap(ax4, sky)

axis(ax4, "equal")
axis(ax4, "tight")

xlim(ax4, xLimits)
ylim(ax4, yLimits)

xlabel(ax4, "$x \, (\mu\mathrm{m})$")

title(ax4, "Local Energy")

cb4 = colorbar(ax4);
cb4.Label.Interpreter = "latex";
cb4.Label.String = "Local Energy, $E$ ($Pa \cdot \mu m$)";

hold(ax4, "on")

% --- Mask contours ---

hMask = gobjects(1,4);

axes(ax1)
hold on
[~, hMask(1)] = contour(T.X, T.Y, Mask, [1 1], ...
    "Color", "k", ...
    "LineWidth", 1.5);

axes(ax2)
hold on
[~, hMask(2)] = contour(T.X, T.Y, Mask, [1 1], ...
    "Color", "k", ...
    "LineWidth", 1.5);

axes(ax3)
hold on
[~, hMask(3)] = contour(T.X, T.Y, Mask, [1 1], ...
    "Color", "k", ...
    "LineWidth", 1.5);

axes(ax4)
hold on
[~, hMask(4)] = contour(T.X, T.Y, Mask, [1 1], ...
    "Color", "k", ...
    "LineWidth", 1.5);

% --- Time loop ---

nFrames = size(T.Tx,3);

for t = 1:nFrames

    % --- Edge color ---

    currentTime_h = hours(MBI_Time(t) - MBI_Time(1));

    edgeColor = "k";

    if ismember(p, actv_pos) && ...
            currentTime_h >= ctrl_start_h && ...
            currentTime_h <= ctrl_start_h + actv_h

        edgeColor = "b";

    end

    % --- Current frame data ---

    Tx = T.Tx(:,:,t);
    Ty = T.Ty(:,:,t);

    Dx = D.Dx(:,:,t);
    Dy = D.Dy(:,:,t);

    Tm = hypot(Tx, Ty);
    E  = 0.5 * (Tx .* Dx + Ty .* Dy);

    % --- Update plots ---

    set(hTx, "CData", Tx)
    set(hTy, "CData", Ty)
    set(hTm, "CData", Tm)
    set(hE,  "CData", E)

    set(hMask, "Color", edgeColor)

    title(tl, "$t = " + string(MBI_Time(t)) + "$", ...
        "Interpreter", "latex");

    drawnow limitrate

    % --- Save frame if required ---

    if saveVideos

        frame = getframe(fig);

        if t == 1

            frameSize = size(frame.cdata);

        elseif any(size(frame.cdata) ~= frameSize)

            frame.cdata = imresize(frame.cdata, frameSize(1:2));

        end

        writeVideo(v, frame)

    end

end

% --- Close video ---

if saveVideos
    close(v)
end

% --- Close figure if not shown ---

if ~showVideos
    close(fig)
end

end

