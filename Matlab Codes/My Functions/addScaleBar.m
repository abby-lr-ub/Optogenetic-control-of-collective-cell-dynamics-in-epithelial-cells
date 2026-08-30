function h = addScaleBar(ax, barLength_um, pxSize_um, opts)
% ADDSCALEBAR  Barra de escala blanca sobre una imagen (estilo microscopia).
%
%   addScaleBar(ax, 100, 0.65)          -> barra de 100 um, 0.65 um/pixel
%   addScaleBar(gca, 100, 1)            -> si los ejes ya estan en micras
%   addScaleBar(ax, 100, 0.65, Location="southwest", FontSize=16)
%
% Dibuja un rectangulo blanco solido en una esquina y la etiqueta
% "100 um" centrada encima, sin bordes ni fondo (estetica del panel b).

arguments
    ax                              (1,1) matlab.graphics.axis.Axes
    barLength_um                    (1,1) double = 100
    pxSize_um                       (1,1) double = 1        % micras por pixel
    opts.Location                   (1,1) string = "southeast"
    opts.Color                            = [1 1 1]
    opts.MarginFrac                 (1,1) double = 0.06     % margen (fraccion del ancho)
    opts.HeightFrac                 (1,1) double = 0.022    % grosor (fraccion del alto)
    opts.ShowLabel                  (1,1) logical = true
    opts.LabelAbove                 (1,1) logical = true
    opts.GapFrac                    (1,1) double = 0.35     % hueco barra-texto (x altura del texto)
    opts.FontSize                   (1,1) double = 14
    opts.FontName                   (1,1) string = "Helvetica"
end

% -------- GEOMETRIA DE LOS EJES --------

xl = xlim(ax);   yl = ylim(ax);
W  = diff(xl);   H  = diff(yl);

barLength_px = barLength_um / pxSize_um;
barHeight    = opts.HeightFrac * H;
mx           = opts.MarginFrac * W;
my           = opts.MarginFrac * H;

% "Abajo" en pantalla depende de YDir (imshow usa 'reverse')
isRev = strcmp(ax.YDir, "reverse");

switch lower(opts.Location)
    case "southeast", x0 = xl(2) - mx - barLength_px;
    case "southwest", x0 = xl(1) + mx;
    case "northeast", x0 = xl(2) - mx - barLength_px;
    case "northwest", x0 = xl(1) + mx;
    otherwise, error("Location no reconocida.")
end

isSouth = startsWith(lower(opts.Location), "south");

if xor(isSouth, isRev)          % borde inferior en pantalla = yl(1)
    y0 = yl(1) + my;
else                            % borde inferior en pantalla = yl(2)
    y0 = yl(2) - my - barHeight;
end

% -------- DIBUJO --------

wasHeld = ishold(ax);
hold(ax, "on")

h.bar = rectangle(ax, ...
    "Position",  [x0 y0 barLength_px barHeight], ...
    "FaceColor", opts.Color, ...
    "EdgeColor", "none", ...
    "Clipping",  "off");

if opts.ShowLabel

    % Anclaje al borde de la barra que queda "arriba" EN PANTALLA.
    % Con YDir reverse el borde superior en pantalla es y0; si no, y0+barHeight.
    if isRev
        yAnchor = y0;
        upSign  = -1;                 % subir en pantalla = restar en datos
    else
        yAnchor = y0 + barHeight;
        upSign  = +1;
    end

    if ~opts.LabelAbove               % etiqueta debajo de la barra
        if isRev
            yAnchor = y0 + barHeight;
        else
            yAnchor = y0;
        end
        upSign = -upSign;
    end

    h.txt = text(ax, ...
        x0 + barLength_px/2, yAnchor, ...
        sprintf("%g %cm", barLength_um, char(956)), ...
        "Color",               opts.Color, ...
        "FontSize",            opts.FontSize, ...
        "FontWeight",          "bold", ...
        "FontName",            opts.FontName, ...
        "Interpreter",         "none", ...  % mu recta, no cursiva
        "HorizontalAlignment", "center", ...
        "VerticalAlignment",   "baseline", ...
        "Clipping",            "off");

    % Separacion proporcional a la ALTURA DEL PROPIO TEXTO, no a la imagen:
    % asi el hueco se ve igual sea cual sea el tamano en pixeles del recorte.
    drawnow limitrate
    txtHeight = h.txt.Extent(4);

    h.txt.Position(2) = ...
        yAnchor + upSign * opts.GapFrac * txtHeight;
end

if ~wasHeld, hold(ax, "off"); end

end
