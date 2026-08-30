# Optogenetic control of collective cell dynamics in epithelial cells

MATLAB analysis code and processed results accompanying my Master's Thesis
(Physics of Complex Systems and Biophysics, University of Barcelona), carried out
at the Integrative Cell and Tissue Dynamics group, IBEC.

## Overview

We combine the optogenetic tool optoGEF-RhoA with Traction Force Microscopy (TFM),
cell segmentation and Particle Image Velocimetry (PIV) to impose a local, reversible
increase in actomyosin contractility in MDCK epithelial cells, and study its effect
on traction forces, cell shape and tissue dynamics in clusters and confluent
monolayers. The repository is organised around the three experiments of the thesis.

## Contents

### `Matlab Codes/`

| Folder | Description |
|---|---|
| `Exp1 TFM Clusters/` | Cluster masking, traction metrics, exponential fits of the activation and relaxation windows, and traction videos |
| `Exp2 TFM Monolayers/` | Traction analysis inside and outside the illuminated stripe, and spatial profiles of the traction field |
| `Exp3 Shape Analysis/` | Cellpose segmentation, morphometric analysis (shape index and aspect ratio) and stripe-contraction PIV |
| `My Functions/` | Helper functions shared across the three experiments |

### `Results/`

Figures, videos and summary files (`.mat`, `.csv`) produced by the scripts above,
mirroring the same three-experiment structure.

## Requirements

MATLAB R2026a with the Image Processing Toolbox and the Medical Imaging Toolbox
Interface for the Cellpose Library (`cyto2` model). Note that
`Exp3 Shape Analysis/CZMBI_Cellpose.m` relies on the internal MBI/CZMBI framework
of the host laboratory, which is not included here; `PIV_analysis.m` is a
standalone script and runs without it.

## Data availability

Raw imaging data, acquisition code (Pycro-Manager) and experimental protocols are
not hosted in this repository due to IBEC data policy. They are available upon
reasonable request.

## Citation

A. López Rivas, *Optogenetic control of collective cell dynamics in epithelial
cells*, Master's Thesis, University of Barcelona, 2026.

## License

MIT — see [LICENSE](LICENSE).
