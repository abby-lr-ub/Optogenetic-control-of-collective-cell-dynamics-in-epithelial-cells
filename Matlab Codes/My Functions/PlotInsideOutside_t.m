
function PlotInsideOutside( ...
    time_h, dataIn, dataOut, GoodPositions, ...
    ctrl_start_h, actv_h, plotColors, ...
    yLabelText, figTitle, outputFile, ...
    showFig, saveFig)

% --- Exit if nothing is required ---

if ~showFig && ~saveFig
    return
end

% --- Figure visibility ---

if showFig
    figVisibility = "on";
else
    figVisibility = "off";
end

% --- Figure creation ---

fig = figure( ...
    "Position", [100 100 1200 400], ...
    "Color", "w", ...
    "Visible", figVisibility);

tiledlayout(1,2, ...
    "Padding", "normal", ...
    "TileSpacing", "normal");

% --- Y limits ---

allValues = [dataIn(GoodPositions,:), dataOut(GoodPositions,:)];

yMin = min(allValues, [], "all", "omitnan");
yMax = max(allValues, [], "all", "omitnan");

padding = 0.05 * (yMax - yMin);

if padding == 0
    padding = 1;
end

yLimits = [yMin - padding, yMax + padding];

% --- Inside mask ---

ax1 = nexttile;
hold(ax1, "on")

for p = GoodPositions

    plot(ax1, time_h, dataIn(p,:), ...
        "LineWidth", 2, ...
        "Color", plotColors(p,:), ...
        "DisplayName", "P" + string(p));

end

xline(ax1, ctrl_start_h, "--k", ...
    "LineWidth", 1.5, ...
    "HandleVisibility", "off");

xline(ax1, ctrl_start_h + actv_h, "--k", ...
    "LineWidth", 1.5, ...
    "HandleVisibility", "off");

ylim(ax1, yLimits)
xlim(ax1, [0, max(time_h)]);

xlabel(ax1, "Time (h)")
ylabel(ax1, yLabelText)
title(ax1, "Inside mask")

legend(ax1, "show")
grid(ax1, "on")
box(ax1, "on")

% --- Outside mask ---

ax2 = nexttile;
hold(ax2, "on")

for p = GoodPositions

    plot(ax2, time_h, dataOut(p,:), ...
        "LineWidth", 2, ...
        "Color", plotColors(p,:), ...
        "DisplayName", "P" + string(p));

end

xline(ax2, ctrl_start_h, "--k", ...
    "LineWidth", 1.5, ...
    "HandleVisibility", "off");

xline(ax2, ctrl_start_h + actv_h, "--k", ...
    "LineWidth", 1.5, ...
    "HandleVisibility", "off");

ylim(ax2, yLimits)
xlim(ax2, [0, max(time_h)]);

xlabel(ax2, "Time (h)")
ylabel(ax2, yLabelText)
title(ax2, "Outside mask")

legend(ax2, "show")
grid(ax2, "on")
box(ax2, "on")

% sgtitle(figTitle)

% --- Save figure ---

if saveFig

    exportgraphics(fig, outputFile, "Resolution", 300);

    savefig(fig, replace(outputFile, ".png", ".fig"));

end

% --- Close figure if not shown ---

if ~showFig
    close(fig)
end

end