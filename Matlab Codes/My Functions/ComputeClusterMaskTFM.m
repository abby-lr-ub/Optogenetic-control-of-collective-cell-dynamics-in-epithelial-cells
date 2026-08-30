
function ClusterMasks = ComputeClusterMasks( ...
    TFM, MBI, imageFolder, clusterFiles, GoodPositions, showFigure, dilationRadius, marginRadius)

% -------- PREALLOCATION --------

ClusterMasks = cell(max(GoodPositions),1);

% -------- LOOP THROUGH POSITIONS --------

for p = GoodPositions

    T = TFM{p};

    imageFile = clusterFiles(p);

    % --- Create mask from image ---

    MaskCluster_img = ...
        CreateMaskCluster( ...
        imageFolder, ...
        imageFile, ...
        showFigure, ...
        dilationRadius, ...
        marginRadius);

    % --- Registration correction ---

    dx = round(MBI.Registration.Shift(p,1,1));
    dy = round(MBI.Registration.Shift(p,1,2));

    MaskCluster_img = ...
        circshift(MaskCluster_img, [dy dx]);

    % --- Crop correction ---

    Crop = T.Settings;

    MaskCluster_crop = ...
        MaskCluster_img(Crop.ROI1, Crop.ROI2);

    % --- Resize to TFM dimensions ---

    MaskCluster = ...
        imresize( ...
        MaskCluster_crop, ...
        size(T.Tx(:,:,1)), ...
        "nearest");

    % --- Save mask ---

    ClusterMasks{p} = logical(MaskCluster);

end

end