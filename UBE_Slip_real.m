function UBE_Slip_real
% UBE_SLIP_REAL  Tow / slip specimen simulation with the tows drawn as bands of real width.
%
%   Run with:   UBE_Slip_real
%
%   Same model, controls and calculations as prog5_gui. The difference is the drawing: instead
%   of one thin line per tow, every tow is drawn as a band whose width stays constant while the
%   fabric shears, so the gaps between tows close up as the specimen locks.
%
%   - "Tow width" is the physical width of one tow in mm. "auto" uses Li/(N+1), the width of the
%     tows in the unsheared centre region (about 5.3 mm for W = 90 mm).
%   - "Draw tows as bands" switches between the band drawing and the original thin lines.
%   - The two tow directions are shaded differently ("/" darker, "\" lighter) and drawn
%     slightly transparent, so overlaps show up as darker crossings and gaps as white space.
%   - Only the two long sides of each tow are outlined; the cut ends are not.
%   - Each existing tow line is used as the CENTRE LINE of a band, and the band ends are cut
%     square, so bands can overhang the thin specimen outline by up to half a tow width.
%
%   - "Parameter set" starts on "Example (current sample)", which loads the current sample
%     dimensions and slip parameter. Type your own values (or use "Slip polynomial...") and the
%     set switches to "Custom"; choose "Example" again to go back to the example values.
%   - "Fix bottom (top moves up)" holds the bottom of the specimen at y = 0 so only the top
%     moves, instead of both ends moving apart symmetrically.
%   - Type the parameters on the left and press "Apply".
%   - Drag the slider to see the specimen at any angle.
%   - "Play" animates the frames ("Stop" interrupts it). With "Constant angle" spacing the
%     frames run from 0 to the locking angle in K steps. With "Constant displacement"
%     spacing they run from 0 to the chosen maximum displacement in equal displacement steps
%     (the maximum cannot exceed the displacement at a locking angle of 85 degrees).
%   - "Save video..." writes the same animation to an .mp4 (or .avi) file.
%   - "Slip polynomial..." sets the coefficients of the third-order polynomial that gives the
%     measured width (and so the slip):  meas_width = a0 + a1*x + a2*x^2 + a3*x^3,
%     where x = 2*t2 is the inter-fibre angle in degrees.
%
%   The number of tows is fixed at N = 11, as in the original script.

    DEG = char(176);
    MAX_ANGLE_DEG = 85;     % largest locking angle; sets the largest allowed displacement
    p = [];                 % current parameters (filled in by applyParams)
    stopFlag = false;       % set by the Stop button
    busy = false;           % true while playing / saving a video
    % Example parameter set: the current sample dimensions and slip parameter.
    % (Edit the values here to change what "Example" loads.)
    example.Lock = 82;                  % locking angle (deg)
    example.Lr = 180;                   % specimen length (mm)
    example.W = 90;                     % specimen width (mm)
    example.K = 50;                     % steps for constant-angle spacing
    example.MinShear = 0;              % minimum shear angle drawn (deg)
    example.Fps = 15;                   % video frame rate
    example.Mode = 2;                   % 1 = constant angle, 2 = constant displacement
    example.DStep = 1;                 % displacement step (mm)
    example.FixBottom = 1;              % 1 = bottom fixed and top moves up, 0 = both ends move
    example.DMax = 100;                 % maximum displacement (mm)
    example.TowW = 'auto';              % tow width in mm, or 'auto' (= Li/(N+1), the tow width in the unsheared centre region)
    example.Bands = 1;                  % 1 = draw tows as bands of real width, 0 = thin lines
    % Slip parameter: meas_width = coef(1) + coef(2)*x + coef(3)*x^2 + coef(4)*x^3  (x = 2*t2, degrees)
    example.Coef = [12.33321933631843, 0.48160420579348, 0.01055559013064, -0.00007021515261];
    coef = example.Coef;                % coefficients currently in use

    % ---------------------------------------------------------------- window
    fig = figure('Name', 'UBE Slip - fabric type', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', ...
        'Position', [100 100 1050 720]);

    ax = axes('Parent', fig, 'Units', 'normalized', ...
        'Position', [0.35 0.09 0.62 0.86], 'Box', 'on');
    % Tow bands first (two directions), then the outline / structure lines on top
    colA = [0.28 0.29 0.33];                        % "/" tows (darker)
    colB = [0.52 0.54 0.60];                        % "\" tows (lighter)
    % Only the two long sides of each tow are outlined (the short cut ends are not), so no
    % zig-zag lines appear where the tow ends meet along the centre of the specimen.
    edgeCol = [0.05 0.05 0.05];
    hTowA = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
        'FaceColor', colA, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
    hEdgeA = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', edgeCol, 'LineWidth', 0.5);
    hTowB = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
        'FaceColor', colB, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
    hEdgeB = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', edgeCol, 'LineWidth', 0.5);
    hLine = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', 'k');

    % ---- Woven fabric handles (hidden when NCF mode is active) ----
    N_STRIPS = 14;          % gradient shading strips per tow
    colA_wov = [0.20 0.21 0.25];   % "/" tows (woven, darker)
    colB_wov = [0.55 0.57 0.63];   % "\" tows (woven, lighter)
    hTowA_wov  = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
        'FaceColor', colA_wov, 'FaceAlpha', 1, 'EdgeColor', 'none');
    hEdgeA_wov = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', edgeCol, 'LineWidth', 0.5);
    hTowB_wov  = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
        'FaceColor', colB_wov, 'FaceAlpha', 1, 'EdgeColor', 'none');
    hEdgeB_wov = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', edgeCol, 'LineWidth', 0.5);
    hOver      = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
        'FaceColor', colA_wov, 'FaceAlpha', 1, 'EdgeColor', colA_wov, 'LineWidth', 1);
    hOverEdge  = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', edgeCol, 'LineWidth', 0.5);
    hLine_wov  = line('Parent', ax, 'XData', NaN, 'YData', NaN, 'Color', 'k');
    % Gradient shading overlays for woven mode
    hShadeAHi = gobjects(N_STRIPS, 1);  hShadeASh = gobjects(N_STRIPS, 1);
    hShadeBHi = gobjects(N_STRIPS, 1);  hShadeBSh = gobjects(N_STRIPS, 1);
    for s_init = 1:N_STRIPS
        hShadeAHi(s_init) = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
            'FaceColor', 'w', 'FaceAlpha', 0, 'EdgeColor', 'none');
        hShadeASh(s_init) = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
            'FaceColor', 'k', 'FaceAlpha', 0, 'EdgeColor', 'none');
        hShadeBHi(s_init) = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
            'FaceColor', 'w', 'FaceAlpha', 0, 'EdgeColor', 'none');
        hShadeBSh(s_init) = patch('Parent', ax, 'XData', NaN(4,1), 'YData', NaN(4,1), ...
            'FaceColor', 'k', 'FaceAlpha', 0, 'EdgeColor', 'none');
    end
    xlabel(ax, 'x (mm)');
    ylabel(ax, 'y (mm)');

    pnl = uipanel('Parent', fig, 'Title', 'Parameters', 'Units', 'normalized', ...
        'Position', [0.01 0.01 0.32 0.98]);

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Parameter set', ...
        'Units', 'normalized', 'Position', [0.04 0.93 0.34 0.036], ...
        'HorizontalAlignment', 'left');
    popPreset = uicontrol('Parent', pnl, 'Style', 'popupmenu', ...
        'String', {'Example (current sample)', 'Custom'}, 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.40 0.932 0.55 0.04], ...
        'BackgroundColor', 'w', 'Callback', @(~,~) onPreset());

    eLock = addField(1, 'Locking angle (deg)',          example.Lock);
    eLr   = addField(2, 'Specimen length Lr (mm)',      example.Lr);
    eW    = addField(3, 'Specimen width W (mm)',        example.W);
    eK    = addField(4, 'Steps K (angle spacing)',      example.K);
    eMin  = addField(5, 'Min. shear angle drawn (deg)', example.MinShear);
    eFps  = addField(6, 'Video frame rate (fps)',       example.Fps);
    eTow  = addField(7, 'Tow width (mm, or auto)',      example.TowW);

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Frame spacing', ...
        'Units', 'normalized', 'Position', [0.04 0.61 0.34 0.036], ...
        'HorizontalAlignment', 'left');
    popMode = uicontrol('Parent', pnl, 'Style', 'popupmenu', ...
        'String', {'Constant angle', 'Constant displacement'}, 'Value', example.Mode, ...
        'Units', 'normalized', 'Position', [0.40 0.612 0.55 0.04], ...
        'BackgroundColor', 'w', 'Callback', @(~,~) onModeChange());
    eDs   = addField(9,  'Displacement step (mm)',      example.DStep);
    eDmax = addField(10, 'Max displacement (mm)',       example.DMax);

    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Slip polynomial...', ...
        'Units', 'normalized', 'Position', [0.04 0.485 0.91 0.04], ...
        'Callback', @(~,~) onSlipPoly());

    chkFix = uicontrol('Parent', pnl, 'Style', 'checkbox', ...
        'String', 'Fix bottom (top moves up)', 'Value', example.FixBottom, ...
        'Units', 'normalized', 'Position', [0.04 0.445 0.91 0.035], ...
        'Callback', @(~,~) onViewChange());
    chkBands = uicontrol('Parent', pnl, 'Style', 'checkbox', ...
        'String', 'Draw tows as bands (real width)', 'Value', example.Bands, ...
        'Units', 'normalized', 'Position', [0.04 0.41 0.91 0.035], ...
        'Callback', @(~,~) onViewChange());

    chkWeave = uicontrol('Parent', pnl, 'Style', 'checkbox', ...
        'String', 'Weave tows over/under', 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.04 0.375 0.91 0.033], ...
        'Callback', @(~,~) onViewChange());

    % Fabric type selector
    bgFabric = uibuttongroup('Parent', pnl, 'Title', 'Fabric type', ...
        'Units', 'normalized', 'Position', [0.04 0.308 0.91 0.065], ...
        'SelectionChangedFcn', @(~,~) onFabricChange());
    rbNCF   = uicontrol('Parent', bgFabric, 'Style', 'radiobutton', ...
        'String', 'Non-crimp fabric', 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.02 0.08 0.48 0.84]);
    rbWoven = uicontrol('Parent', bgFabric, 'Style', 'radiobutton', ...
        'String', 'Woven fabric', 'Value', 0, ...
        'Units', 'normalized', 'Position', [0.52 0.08 0.46 0.84]);

    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Apply', ...
        'Units', 'normalized', 'Position', [0.04 0.260 0.91 0.04], ...
        'Callback', @(~,~) onApply());

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Angle (deg)', ...
        'Units', 'normalized', 'Position', [0.04 0.218 0.91 0.032], ...
        'HorizontalAlignment', 'left');
    slider = uicontrol('Parent', pnl, 'Style', 'slider', ...
        'Min', 0, 'Max', 82, 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.04 0.178 0.91 0.04], ...
        'Callback', @(~,~) onSlide());
    try
        addlistener(slider, 'ContinuousValueChange', @(~,~) onSlide());
    catch
        % older releases: the slider then updates when released
    end

    btnPlay = uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Play', ...
        'Units', 'normalized', 'Position', [0.04 0.118 0.44 0.05], ...
        'Callback', @(~,~) onPlay());
    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Stop', ...
        'Units', 'normalized', 'Position', [0.51 0.118 0.44 0.05], ...
        'Callback', @(~,~) onStop());
    btnSave = uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Save video...', ...
        'Units', 'normalized', 'Position', [0.04 0.058 0.91 0.05], ...
        'Callback', @(~,~) onSave());

    txtInfo = uicontrol('Parent', pnl, 'Style', 'text', 'String', '', ...
        'Units', 'normalized', 'Position', [0.04 0.01 0.91 0.042], ...
        'HorizontalAlignment', 'left');

    updateEnable();
    onFabricChange();   % set initial chkWeave enable state
    onApply();              % draw the fully-locked shape on start-up

    % ------------------------------------------------------------- callbacks
    function e = addField(row, label, value)
        yPos = 0.93 - row*0.04;
        uicontrol('Parent', pnl, 'Style', 'text', 'String', label, ...
            'Units', 'normalized', 'Position', [0.04 yPos 0.62 0.036], ...
            'HorizontalAlignment', 'left');
        e = uicontrol('Parent', pnl, 'Style', 'edit', 'String', num2str(value), ...
            'Units', 'normalized', 'Position', [0.68 yPos+0.003 0.27 0.036], ...
            'BackgroundColor', 'w', 'Callback', @(~,~) markCustom());
    end

    function markCustom()
        % Any manual change switches the parameter set to "Custom"
        set(popPreset, 'Value', 2);
    end

    function onFabricChange()
        % Enable the weave checkbox only in woven mode
        if get(rbWoven, 'Value')
            set(chkWeave, 'Enable', 'on');
        else
            set(chkWeave, 'Enable', 'off');
        end
        if ~isempty(p), drawAt(get(slider, 'Value')*pi/180); end
    end

    function onViewChange()
        % Redraw the current frame after changing the view options (fixed bottom, bands)
        markCustom();
        if busy || isempty(p), return; end
        if applyParams()
            drawAt(get(slider, 'Value')*pi/180);
        end
    end

    function onModeChange()
        updateEnable();
        markCustom();
    end

    function onPreset()
        % "Example" reloads the example values; "Custom" keeps whatever is entered
        if get(popPreset, 'Value') == 1
            if busy
                set(popPreset, 'Value', 2);
                return
            end
            loadExample();
        end
    end

    function loadExample()
        set(eLock, 'String', num2str(example.Lock));
        set(eLr,   'String', num2str(example.Lr));
        set(eW,    'String', num2str(example.W));
        set(eK,    'String', num2str(example.K));
        set(eMin,  'String', num2str(example.MinShear));
        set(eFps,  'String', num2str(example.Fps));
        set(eDs,   'String', num2str(example.DStep));
        set(eDmax, 'String', num2str(example.DMax));
        set(popMode, 'Value', example.Mode);
        set(chkFix, 'Value', example.FixBottom);
        set(chkBands, 'Value', example.Bands);
        set(eTow, 'String', num2str(example.TowW));
        coef = example.Coef;
        updateEnable();
        onApply();
    end

    function ok = applyParams()
        byDisp = get(popMode, 'Value') == 2;
        towStr = strtrim(get(eTow, 'String'));
        isAuto = isempty(towStr) || strcmpi(towStr, 'auto');
        if isAuto, towW = NaN; else, towW = str2double(towStr); end
        v = [str2double(get(eLock, 'String')), str2double(get(eLr, 'String')), ...
             str2double(get(eW, 'String')),    str2double(get(eK, 'String')), ...
             str2double(get(eMin, 'String')),  str2double(get(eFps, 'String')), ...
             str2double(get(eDs, 'String')),   str2double(get(eDmax, 'String'))];
        if byDisp
            v(1) = MAX_ANGLE_DEG;                   % locking angle not used: search up to 85 deg
            v(4) = 1;                               % K not used
        else
            v(7:8) = 1;                             % displacement fields not used
        end
        ok = all(isfinite(v)) && v(1) > 0 && v(1) < 90 && v(2) > 0 && v(3) > 0 ...
             && v(4) >= 1 && v(5) >= 0 && v(6) > 0 && v(7) > 0 && v(8) > 0;
        ok = ok && (isAuto || (isfinite(towW) && towW > 0));
        if ~ok
            set(txtInfo, 'String', {'Invalid input.', ...
                'The locking angle must be between 0 and 90 degrees;', ...
                'lengths, K, the frame rate and the displacement values must be positive;', ...
                'the tow width must be "auto" or a positive number.'});
            return
        end
        dCap = kinematics(MAX_ANGLE_DEG*pi/180, struct('W', v(3), 'Coef', coef));   % displacement at 85 deg
        if byDisp
            v(8) = min(v(8), floor(dCap*100)/100);  % cannot exceed the 85-degree displacement
            set(eDmax, 'String', sprintf('%g', v(8)));
            if v(8) < v(7)
                ok = false;
                set(txtInfo, 'String', {'The maximum displacement must be at least', ...
                    'one displacement step.'});
                return
            end
            if v(8)/v(7) > 5000
                ok = false;
                set(txtInfo, 'String', {'The displacement step is too small', ...
                    '(more than 5000 frames).'});
                return
            end
        end
        p.LockDeg  = v(1);
        p.LockRad  = v(1)*pi/180;
        p.Lr       = v(2);
        p.W        = v(3);
        p.K        = max(1, round(v(4)));
        p.MinShear = v(5);
        p.Fps      = v(6);
        p.N        = 11;
        p.Coef     = coef;
        p.FixBottom = get(chkFix, 'Value') == 1;
        p.TowW     = towW;                          % NaN = auto
        p.Bands    = get(chkBands, 'Value') == 1;
        p.Weave    = p.Bands && get(chkWeave, 'Value') == 1;
        p.NStrips  = N_STRIPS;
        p.ByDisp   = byDisp;
        p.DStep    = v(7);
        p.DMax     = v(8);
        p.DCap     = dCap;
        p.SearchRad = MAX_ANGLE_DEG*pi/180;
        nSteps = p.K;
        if byDisp
            th = anglesForDisplacement(p);          % last frame is at the max displacement
            p.LockRad = th(end);
            p.LockDeg = th(end)*180/pi;
            nSteps = max(1, numel(th) - 1);
        else
            set(eK, 'String', num2str(p.K));
        end
        set(slider, 'Value', min(get(slider, 'Value'), p.LockDeg));
        set(slider, 'Min', 0, 'Max', p.LockDeg, ...
            'SliderStep', [min(1, 1/nSteps), min(1, 5/nSteps)]);
        if p.FixBottom
            % Bottom stays at y = 0; leave room for the top at the longest frame
            if get(rbWoven, 'Value')
                frEnd = computeFrame_wov(p.LockRad, p);
            else
                frEnd = computeFrame(p.LockRad, p);
            end
            Ltot = frEnd.Ltot;
            set(ax, 'XLim', [-p.Lr p.Lr], 'YLim', [-0.05*Ltot, 1.05*Ltot]);
        else
            set(ax, 'XLim', [-p.Lr p.Lr], 'YLim', [-p.Lr p.Lr]);
        end
        daspect(ax, [1 1 1]);
    end

    function shown = drawAt(theta)
        isWoven = get(rbWoven, 'Value') == 1;
        nan4 = NaN(4,1);

        if isWoven
            % ---- Woven fabric mode ----
            set(ax, 'Color', [0.93 0.92 0.90]);
            [fr, dispMm, shearDeg] = computeFrame_wov(theta, p);
            shown = shearDeg >= p.MinShear - 1e-9;
            % Hide NCF handles
            set(hTowA,  'XData', nan4, 'YData', nan4);
            set(hEdgeA, 'XData', NaN,  'YData', NaN);
            set(hTowB,  'XData', nan4, 'YData', nan4);
            set(hEdgeB, 'XData', NaN,  'YData', NaN);
            set(hLine,  'XData', NaN,  'YData', NaN);
            if shown
                set(hTowA_wov,  'XData', fr.XA,  'YData', fr.YA);
                set(hEdgeA_wov, 'XData', fr.EAx, 'YData', fr.EAy);
                set(hTowB_wov,  'XData', fr.XB,  'YData', fr.YB);
                set(hEdgeB_wov, 'XData', fr.EBx, 'YData', fr.EBy);
                set(hOver,      'XData', fr.OX,  'YData', fr.OY);
                set(hOverEdge,  'XData', fr.OEx, 'YData', fr.OEy);
                set(hLine_wov,  'XData', fr.XS,  'YData', fr.YS);
                for s_draw = 1:N_STRIPS
                    set(hShadeAHi(s_draw), 'XData', fr.ShadeAX{s_draw}, 'YData', fr.ShadeAY{s_draw}, ...
                        'FaceAlpha', max(0,  fr.ShadeAA(s_draw)));
                    set(hShadeASh(s_draw), 'XData', fr.ShadeAX{s_draw}, 'YData', fr.ShadeAY{s_draw}, ...
                        'FaceAlpha', max(0, -fr.ShadeAA(s_draw)));
                    set(hShadeBHi(s_draw), 'XData', fr.ShadeBX{s_draw}, 'YData', fr.ShadeBY{s_draw}, ...
                        'FaceAlpha', max(0,  fr.ShadeBA(s_draw)));
                    set(hShadeBSh(s_draw), 'XData', fr.ShadeBX{s_draw}, 'YData', fr.ShadeBY{s_draw}, ...
                        'FaceAlpha', max(0, -fr.ShadeBA(s_draw)));
                end
                note = '';
            else
                set(hTowA_wov,  'XData', nan4, 'YData', nan4);
                set(hEdgeA_wov, 'XData', NaN,  'YData', NaN);
                set(hTowB_wov,  'XData', nan4, 'YData', nan4);
                set(hEdgeB_wov, 'XData', NaN,  'YData', NaN);
                set(hOver,      'XData', nan4, 'YData', nan4);
                set(hOverEdge,  'XData', NaN,  'YData', NaN);
                set(hLine_wov,  'XData', NaN,  'YData', NaN);
                for s_draw = 1:N_STRIPS
                    set(hShadeAHi(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                    set(hShadeASh(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                    set(hShadeBHi(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                    set(hShadeBSh(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                end
                note = sprintf('Shear angle below %.1f%s: not drawn', p.MinShear, DEG);
            end

        else
            % ---- Non-crimp fabric mode ----
            set(ax, 'Color', 'w');
            [fr, dispMm, shearDeg] = computeFrame(theta, p);
            shown = shearDeg >= p.MinShear - 1e-9;
            % Hide woven handles
            set(hTowA_wov,  'XData', nan4, 'YData', nan4);
            set(hEdgeA_wov, 'XData', NaN,  'YData', NaN);
            set(hTowB_wov,  'XData', nan4, 'YData', nan4);
            set(hEdgeB_wov, 'XData', NaN,  'YData', NaN);
            set(hOver,      'XData', nan4, 'YData', nan4);
            set(hOverEdge,  'XData', NaN,  'YData', NaN);
            set(hLine_wov,  'XData', NaN,  'YData', NaN);
            for s_draw = 1:N_STRIPS
                set(hShadeAHi(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                set(hShadeASh(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                set(hShadeBHi(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
                set(hShadeBSh(s_draw), 'XData', nan4, 'YData', nan4, 'FaceAlpha', 0);
            end
            if shown
                set(hTowA,  'XData', fr.XA,  'YData', fr.YA);
                set(hEdgeA, 'XData', fr.EAx, 'YData', fr.EAy);
                set(hTowB,  'XData', fr.XB,  'YData', fr.YB);
                set(hEdgeB, 'XData', fr.EBx, 'YData', fr.EBy);
                set(hLine,  'XData', fr.XS,  'YData', fr.YS);
                note = '';
            else
                set(hTowA,  'XData', nan4, 'YData', nan4);
                set(hEdgeA, 'XData', NaN,  'YData', NaN);
                set(hTowB,  'XData', nan4, 'YData', nan4);
                set(hEdgeB, 'XData', NaN,  'YData', NaN);
                set(hLine,  'XData', NaN,  'YData', NaN);
                note = sprintf('Shear angle below %.1f%s: not drawn', p.MinShear, DEG);
            end
        end
        title(ax, sprintf('Angle %.1f%s     Displacement %.2f mm', ...
            theta*180/pi, DEG, dispMm));
        info = { ...
            sprintf('Angle:  %.2f%s', theta*180/pi, DEG), ...
            sprintf('Shear angle:  %.2f%s', shearDeg, DEG), ...
            sprintf('Displacement:  %.2f mm', dispMm), ...
            note};
        if p.Bands
            info{end+1} = sprintf('Tow width:  %.2f mm', fr.TowW);
        end
        if p.ByDisp
            info{end+1} = sprintf('Largest allowed displacement (%d%s):  %.2f mm', ...
                MAX_ANGLE_DEG, DEG, p.DCap);
        end
        set(txtInfo, 'String', info);
    end

    function updateEnable()
        % Angle-mode fields and displacement-mode fields are only active in their own mode
        if get(popMode, 'Value') == 2
            set([eLock eK], 'Enable', 'off');
            set([eDs eDmax], 'Enable', 'on');
        else
            set([eLock eK], 'Enable', 'on');
            set([eDs eDmax], 'Enable', 'off');
        end
    end

    function thetas = frameAngles()
        % Angles of the frames to show / record, according to the "Frame spacing" choice
        if p.ByDisp
            thetas = anglesForDisplacement(p);      % equal displacement steps
        else
            thetas = linspace(0, p.LockRad, p.K + 1);   % equal angle steps
        end
    end

    function onApply()
        if busy, return; end
        if applyParams()
            set(slider, 'Value', p.LockDeg);
            drawAt(p.LockRad);
        end
    end

    function onSlipPoly()
        % Ask for the four coefficients of the measured-width polynomial
        if busy, return; end
        labels = {'a0  (constant)', 'a1  (x)', 'a2  (x^2)', 'a3  (x^3)'};
        defs = arrayfun(@(c) sprintf('%.16g', c), coef, 'UniformOutput', false);
        answer = inputdlg(labels, ...
            'meas_width = a0 + a1*x + a2*x^2 + a3*x^3   (x = 2*t2 in degrees)', ...
            [1 70], defs);
        if isempty(answer), return; end
        newCoef = str2double(answer(:)');
        if numel(newCoef) ~= 4 || any(~isfinite(newCoef))
            errordlg('All four coefficients must be numbers.', 'Slip polynomial');
            return
        end
        coef = newCoef;
        markCustom();
        onApply();
    end

    function onSlide()
        if busy || isempty(p), return; end
        drawAt(get(slider, 'Value')*pi/180);
    end

    function onStop()
        stopFlag = true;
    end

    function onPlay()
        if busy, return; end
        if ~applyParams(), return; end
        busy = true;
        stopFlag = false;
        set(btnPlay, 'Enable', 'off');
        set(btnSave, 'Enable', 'off');
        try
            thetas = frameAngles();
            for i = 1:numel(thetas)
                if stopFlag || ~ishandle(fig), break; end
                set(slider, 'Value', min(thetas(i)*180/pi, p.LockDeg));
                if drawAt(thetas(i))
                    drawnow;
                    pause(1/p.Fps);
                end
            end
        catch ME
            busy = false;
            if ishandle(fig)
                set(btnPlay, 'Enable', 'on');
                set(btnSave, 'Enable', 'on');
            end
            rethrow(ME);
        end
        busy = false;
        if ishandle(fig)
            set(btnPlay, 'Enable', 'on');
            set(btnSave, 'Enable', 'on');
        end
    end

    function onSave()
        if busy, return; end
        if ~applyParams(), return; end
        [fn, pa] = uiputfile({'*.mp4', 'MPEG-4 / H.264 - opens in QuickTime Player (*.mp4)'; ...
                              '*.avi', 'Motion JPEG AVI - not supported by QuickTime Player (*.avi)'}, ...
                             'Save video as', 'UBE_Slip_real_4_video.mp4');
        if isequal(fn, 0), return; end
        [~, ~, ext] = fileparts(fn);
        if strcmpi(ext, '.avi')
            profile = 'Motion JPEG AVI';
        else
            profile = 'MPEG-4';
        end
        try
            vw = VideoWriter(fullfile(pa, fn), profile);
        catch ME
            errordlg({['Could not create the video file: ' ME.message], '', ...
                'The MPEG-4 (QuickTime-compatible) format is not available on every system', ...
                '(for example some Linux installations). Try the AVI option instead, then convert', ...
                'it to .mp4 with a tool such as HandBrake or ffmpeg if you need QuickTime.'}, ...
                'Save video');
            return
        end
        vw.FrameRate = p.Fps;
        try, vw.Quality = 95; catch, end            % high quality (MPEG-4 profile)
        open(vw);

        busy = true;
        stopFlag = false;
        set(btnPlay, 'Enable', 'off');
        set(btnSave, 'Enable', 'off');
        nWritten = 0;
        try
            thetas = frameAngles();
            for i = 1:numel(thetas)
                if stopFlag || ~ishandle(fig), break; end
                set(slider, 'Value', min(thetas(i)*180/pi, p.LockDeg));
                if drawAt(thetas(i))
                    drawnow;
                    writeVideo(vw, evenFrame(getframe(ax).cdata));
                    nWritten = nWritten + 1;
                end
            end
            close(vw);
        catch ME
            try, close(vw); catch, end
            busy = false;
            if ishandle(fig)
                set(btnPlay, 'Enable', 'on');
                set(btnSave, 'Enable', 'on');
            end
            rethrow(ME);
        end
        busy = false;
        if ishandle(fig)
            set(btnPlay, 'Enable', 'on');
            set(btnSave, 'Enable', 'on');
            if nWritten == 0
                set(txtInfo, 'String', 'No frames were drawn, so the video is empty.');
            else
                finfo = dir(fullfile(pa, fn));
                if isempty(finfo), sz = 0; else, sz = finfo(1).bytes/1024; end
                set(txtInfo, 'String', sprintf('Saved %d frames (%.0f KB) to %s', ...
                    nWritten, sz, fullfile(pa, fn)));
            end
        end
    end
end


function img = evenFrame(img)
% EVENFRAME  H.264 (.mp4, QuickTime Player) needs an even width and height; repeat the last
% pixel row / column if needed. Every frame gets the same size, so the video stays consistent.
    if mod(size(img, 1), 2), img(end+1, :, :) = img(end, :, :); end
    if mod(size(img, 2), 2), img(:, end+1, :) = img(:, end, :); end
end


function [displacement, S] = kinematics(theta, p)
% KINEMATICS  Slip S and displacement from the measured-width fit (works on arrays of theta).
    W  = p.W;
    L  = 2*W;
    Li = sqrt((W/2)^2 + (L/4)^2);
    t2 = pi/4 - theta/2;                            % Half inter-fibre angle
    t6 = t2/pi*180;
    c = p.Coef;
    x = t6*2;                                       % inter-fibre angle in degrees
    meas_width = c(1) + c(2)*x + c(3)*x.^2 + c(4)*x.^3;
    S = max((meas_width - 2*Li*sin(t2))./(2*sin(t2)), 0);
    displacement = 2*cos(t2).*(Li + S) - sqrt(2)*Li;
end


function thetas = anglesForDisplacement(p)
% ANGLESFORDISPLACEMENT  Angles giving displacements 0, dStep, 2*dStep, ... without going
% past the chosen maximum displacement p.DMax (itself limited to the displacement at 85 deg).
    thFine = linspace(0, p.SearchRad, 5000);
    Dfine  = kinematics(thFine, p);
    [~, iMax] = max(Dfine);                         % use only the rising part of the curve
    [Du, iu]  = unique(Dfine(1:iMax));
    thGrid = thFine(1:iMax);
    thGrid = thGrid(iu);
    dEnd = min(p.DMax, Du(end));
    targets = 0:p.DStep:(dEnd + 1e-9);              % equal displacement steps up to the maximum
    targets = min(max(targets, Du(1)), Du(end));
    thetas = interp1(Du, thGrid, targets);
end


function [fr, displacement, t7] = computeFrame(theta, p)
% COMPUTEFRAME  Geometry of the specimen at one angle (same maths as prog5_fixed.m,
% evaluated for the final pass Ps = K).
% fr.XS / fr.YS : NaN-separated outline lines (plus the tow centre lines if bands are off)
% fr.XA,YA / fr.XB,YB : tow bands as 4-row polygon matrices ("/" and "\" tows)
% fr.EAx,EAy / fr.EBx,EBy : NaN-separated long side edges of those bands
% fr.Ltot : specimen length, fr.TowW : tow width used

    Lr = p.Lr;  W = p.W;  K = p.K;  N = p.N;

    L  = 2*W;                                       % Ideal length of specimen
    R1 = Lr/W;                                      % Ratio of length to width
    R3 = R1 - 2;
    Li = sqrt((W/2)^2 + (L/4)^2);                   % Side length of the centre region

    d  = Li*cos(pi/4 - theta/2) - Li/sqrt(2);       % Extension of one side (vertical)
    f  = Li/sqrt(2) - Li*sin(pi/4 - theta/2);       % Contraction of one side (horizontal)
    d2 = R3*d;

    % Angles
    t1 = atan(f/(L/2 + d));
    t3 = (45/180)*pi;
    t2 = t3 - (theta/2);                            % Half inter-fibre angle
    t4 = pi/2 - 2*t2;                               % Shear angle (rad)
    t6 = t2/pi*180;
    t7 = t4/pi*180;                                 % Shear angle (deg)

    % Lengths
    L2 = sqrt((W/2)^2 + (L/4)^2)/(N+1);
    L4 = sqrt(f^2 + (-L/2 - d)^2)/(N+1);

    % Slip from measured kinematics
    [displacement, S] = kinematics(theta, p);
    t3a = (45/180)*pi;

    % Variables for ratios
    R0 = Lr/2 - W;
    Mh = (N+1)/2;
    Mv = ((R1-2)/2)*(N+1);
    N3 = ((Lr-L)/W)*Mh;

    % Slip
    xs  = S*sin(t2)/K;
    ys  = S*cos(t2)/K;
    ys2 = R3*ys;
    cs  = S*sin(t3a);
    Er  = R0 + ys2 + d2;

    Ps = K;                                         % final pass
    L7  = (W/2 - f + Ps*xs)/(N+1);
    L8  = (L/4 + d + Ps*ys)/(N+1);
    L9  = (f - cs - (Ps*xs))/(N+1);
    L10 = (L/2 + d + (Ps*ys - cs))/(N+1);
    L11 = (W/2 - f + Ps*xs)/Mh;
    L12 = (L/4 + d + (Ps*ys))/Mh;
    L13 = (L/2)/(N+1);
    L14 = W/(N+1);
    Z1  = Er/N3;
    Z2  = (W/2 - f + Ps*xs)/Mh;

    % Each tow is drawn in all four quadrants, NaN-separated so one plot call can draw all
    segx = @(a) [a(:); NaN; -a(:); NaN; a(:); NaN; -a(:); NaN];
    segy = @(b) [b(:); NaN; b(:); NaN; -b(:); NaN; -b(:); NaN];
    XS = [];  YS = [];
    TW = [];                                        % tow centre lines, one row [x1 y1 x2 y2] each

    % Outer line sequence
    x = [0, W/2, 0, W/2 - f + Ps*xs, W/2 - cs];
    y = [L/2 + d + (Ps*ys), L/2 + d + (Ps*ys), L/4 + d + (Ps*ys), 0, L/2 + d + (Ps*ys - cs)];
    XS = [XS; segx(x)];  YS = [YS; segy(y + Er)];

    % Outer line from top to bottom
    x1 = [W/2, W/2 - f];
    y1 = [L/2 + d + (Ps*ys), (Ps*ys)];
    XS = [XS; segx(x1)];  YS = [YS; segy(y1 + Er)];

    % Straight line showing the middle part of the specimen
    x2 = [W/2 - f + Ps*xs, W/2 - f + Ps*xs];
    y2 = [Er, 0];
    XS = [XS; segx(x2)];  YS = [YS; segy(y2)];

    % Downwards tows, right-triangular region (/ direction a-c)
    for P = 0:N
        a1 = [W/2 - cs - P*L9, P*L7];
        b1 = [L/2 + d + (Ps*ys - cs) - P*L10, L/4 + d + (Ps*ys) - P*L8];
        TW = [TW; towRow(a1, b1 + Er)];
    end

    % Upwards tows, right-triangular region (\ direction a-b)
    for P = 0:N
        a2 = [W/2 - P*L4*sin(t1), W/2 - P*L2*cos(t3)];
        b2 = [L/2 + d - P*L4*cos(t1) + (Ps*ys), L/2 + d - P*L2*sin(t3) + (Ps*ys)];
        TW = [TW; towRow(a2, b2 + Er)];
    end

    % Bottom half tows, centre region (/ direction c-e)
    for P = 0:Mh
        Q = P + Mh;
        a3 = [Q*L7, P*L11];
        b3 = [L/4 + d + (Ps*ys) - Q*L8, 0];
        TW = [TW; towRow(a3, b3 + Er)];
    end

    % Top half tows, centre region (/ direction c-g)
    for P = 0:Mh
        Q = Mh - P;
        a4 = [P*L7, 0];
        b4 = [L/4 + d + (Ps*ys) - P*L8, Q*L12];
        TW = [TW; towRow(a4, b4 + Er)];
    end

    % Vertical to horizontal tows, centre region (\ direction e-g)
    for P = 0:Mh
        a5 = [P*L11, 0];
        b5 = [0, P*L12];
        TW = [TW; towRow(a5, b5 + Er)];
    end

    % Bottom half tows, upper-triangular region (\ direction b-f)
    for P = (N+1)/2:(N+1)
        Q = (N+1) - P;
        a6 = [W/2 - P*L2*cos(t3), 0];
        b6 = [L/2 + d - P*L2*sin(t3) + Ps*ys, L/4 + d + Q*L13 + Ps*ys];
        TW = [TW; towRow(a6, b6 + Er)];
    end

    % Top half tows, upper-triangular region (\ direction b-d)
    for P = 0:(N+1)/2
        a7 = [W/2 - P*L2*cos(t3), W/2 - P*L14];
        b7 = [L/2 + d - P*L2*sin(t3) + Ps*ys, L/2 + d + Ps*ys];
        TW = [TW; towRow(a7, b7 + Er)];
    end

    % Tows, upper-triangular region (/ direction d-f)
    for P = 0:(N+1)/2
        a8 = [W/2 - P*L14, 0];
        b8 = [L/2 + d + Ps*ys, L/4 + d + P*L13 + Ps*ys];
        TW = [TW; towRow(a8, b8 + Er)];
    end

    % Tows for ratio of more than 2
    for P = 0:Mh
        Q1 = Mv - P;
        if Q1 <= 0
            break
        end

        U = [W/2 - f + Ps*xs, W/2 - f + Ps*xs - P*Z2];
        V = [Er - P*Z1, Er];
        TW = [TW; towRow(U, V)];

        U1 = [0, P*Z2];
        V1 = [Er - P*Z1, Er];
        TW = [TW; towRow(U1, V1)];

        U2 = [W/2 - f + Ps*xs, W/2 - f + Ps*xs - P*Z2];
        V2 = [P*Z1, 0];
        TW = [TW; towRow(U2, V2)];

        U3 = [0, P*Z2];
        V3 = [P*Z1, 0];
        TW = [TW; towRow(U3, V3)];
    end

    % Cross-lines for ratio above 2.5
    for P = 0:(Mv - Mh)
        Q2 = Mv - P;
        if Q2 <= 0
            break
        end

        U4 = [W/2 - f + Ps*xs, 0];
        V4 = [Er - P*Z1, Er - (Mh*Z1) - P*Z1];
        TW = [TW; towRow(U4, V4)];

        U5 = [0, W/2 - f + Ps*xs];
        V5 = [Er - P*Z1, Er - (Mh*Z1) - P*Z1];
        TW = [TW; towRow(U5, V5)];
    end

    % Diagonal tows for the remaining ratios (the original only skips this for R1 = 2 or R1 > 2.5)
    G2 = (W/2 - f + Ps*xs)/(2*Z2);
    for P = 0:Mh - G2
        Q = Mh - G2 - P;
        if R1 == 2 || R1 > 2.5
            break
        end

        U6 = [P*Z2, W/2 - f + Ps*xs - Q*Z2];
        V6 = [0, Er];
        TW = [TW; towRow(U6, V6)];

        U7 = [P*Z2, W/2 - f + Ps*xs - Q*Z2];
        V7 = [Er, 0];
        TW = [TW; towRow(U7, V7)];
    end

    % Mirror the tow centre lines into the four quadrants (columns: x1 y1 x2 y2)
    TWm = [TW; TW.*[-1 1 -1 1]; TW.*[1 -1 1 -1]; TW.*[-1 -1 -1 -1]];
    segLen = hypot(TWm(:,3) - TWm(:,1), TWm(:,4) - TWm(:,2));
    TWm = TWm(segLen > 1e-6, :);                    % drop zero-length segments

    % Specimen length, and optionally hold the bottom at y = 0 so only the top moves
    % (the whole drawing is shifted up by its half-length, so the top moves at the full rate)
    allY = [YS; TWm(:,2); TWm(:,4)];
    fr.Ltot = max(allY) - min(allY);
    if p.FixBottom
        yShift = min(allY);
        YS = YS - yShift;
        TWm(:, [2 4]) = TWm(:, [2 4]) - yShift;
    end

    % Tow width: constant physical width, 'auto' = tow spacing in the unsheared centre region
    towW = p.TowW;
    if isnan(towW)
        towW = Li/(N+1);
    end
    fr.TowW = towW;

    if p.Bands
        [fr.XA, fr.YA, fr.XB, fr.YB, fr.EAx, fr.EAy, fr.EBx, fr.EBy] = towBands(TWm, towW/2);
    else
        % Original thin-line drawing: add the tow centre lines to the line data
        fr.XA = NaN(4,1);  fr.YA = NaN(4,1);
        fr.XB = NaN(4,1);  fr.YB = NaN(4,1);
        fr.EAx = NaN;  fr.EAy = NaN;  fr.EBx = NaN;  fr.EBy = NaN;
        nT = size(TWm, 1);
        XL = [TWm(:,1), TWm(:,3), NaN(nT,1)].';
        YL = [TWm(:,2), TWm(:,4), NaN(nT,1)].';
        XS = [XS; XL(:)];
        YS = [YS; YL(:)];
    end
    fr.XS = XS;
    fr.YS = YS;
end


function r = towRow(a, b)
% TOWROW  One tow centre line from its two x values (a) and two y values (b).
    r = [a(1), b(1), a(2), b(2)];
end


function [XA, YA, XB, YB, EAx, EAy, EBx, EBy] = towBands(T, hw)
% TOWBANDS  Turn tow centre lines (rows [x1 y1 x2 y2]) into bands of half-width hw.
% Returns 4-row polygon matrices for the "/" tows (A) and the "\" tows (B).
    dx  = T(:,3) - T(:,1);
    dy  = T(:,4) - T(:,2);
    len = hypot(dx, dy);
    nx  = -dy./len*hw;                              % half-width offset, perpendicular to the tow
    ny  =  dx./len*hw;
    XQ = [T(:,1)+nx, T(:,3)+nx, T(:,3)-nx, T(:,1)-nx].';
    YQ = [T(:,2)+ny, T(:,4)+ny, T(:,4)-ny, T(:,2)-ny].';
    isA = (dx.*dy) >= 0;                            % rising ("/") tows
    XA = XQ(:, isA);   YA = YQ(:, isA);
    XB = XQ(:, ~isA);  YB = YQ(:, ~isA);
    if isempty(XA), XA = NaN(4,1); YA = NaN(4,1); end
    if isempty(XB), XB = NaN(4,1); YB = NaN(4,1); end

    % Outline only the two long sides of each band (corner 1 -> 2 and corner 4 -> 3), not the ends
    edg = @(Q) reshape([Q(1,:); Q(2,:); NaN(1, size(Q,2)); Q(4,:); Q(3,:); NaN(1, size(Q,2))], [], 1);
    EAx = edg(XA);  EAy = edg(YA);
    EBx = edg(XB);  EBy = edg(YB);
end




function [fr, displacement, t7] = computeFrame_wov(theta, p)
% COMPUTEFRAME  Geometry of the specimen at one angle (same maths as prog5_fixed.m,
% evaluated for the final pass Ps = K).
% fr.XS / fr.YS : NaN-separated outline lines (plus the tow centre lines if bands are off)
% fr.XA,YA / fr.XB,YB : tow bands as 4-row polygon matrices ("/" and "\" tows)
% fr.EAx,EAy / fr.EBx,EBy : NaN-separated long side edges of those bands
% fr.Ltot : specimen length, fr.TowW : tow width used

    Lr = p.Lr;  W = p.W;  K = p.K;  N = p.N;

    L  = 2*W;                                       % Ideal length of specimen
    R1 = Lr/W;                                      % Ratio of length to width
    R3 = R1 - 2;
    Li = sqrt((W/2)^2 + (L/4)^2);                   % Side length of the centre region

    d  = Li*cos(pi/4 - theta/2) - Li/sqrt(2);       % Extension of one side (vertical)
    f  = Li/sqrt(2) - Li*sin(pi/4 - theta/2);       % Contraction of one side (horizontal)
    d2 = R3*d;

    % Angles
    t1 = atan(f/(L/2 + d));
    t3 = (45/180)*pi;
    t2 = t3 - (theta/2);                            % Half inter-fibre angle
    t4 = pi/2 - 2*t2;                               % Shear angle (rad)
    t6 = t2/pi*180;
    t7 = t4/pi*180;                                 % Shear angle (deg)

    % Lengths
    L2 = sqrt((W/2)^2 + (L/4)^2)/(N+1);
    L4 = sqrt(f^2 + (-L/2 - d)^2)/(N+1);

    % Slip from measured kinematics
    [displacement, S] = kinematics(theta, p);
    t3a = (45/180)*pi;

    % Variables for ratios
    R0 = Lr/2 - W;
    Mh = (N+1)/2;
    Mv = ((R1-2)/2)*(N+1);
    N3 = ((Lr-L)/W)*Mh;

    % Slip
    xs  = S*sin(t2)/K;
    ys  = S*cos(t2)/K;
    ys2 = R3*ys;
    cs  = S*sin(t3a);
    Er  = R0 + ys2 + d2;

    Ps = K;                                         % final pass
    L7  = (W/2 - f + Ps*xs)/(N+1);
    L8  = (L/4 + d + Ps*ys)/(N+1);
    L9  = (f - cs - (Ps*xs))/(N+1);
    L10 = (L/2 + d + (Ps*ys - cs))/(N+1);
    L11 = (W/2 - f + Ps*xs)/Mh;
    L12 = (L/4 + d + (Ps*ys))/Mh;
    L13 = (L/2)/(N+1);
    L14 = W/(N+1);
    Z1  = Er/N3;
    Z2  = (W/2 - f + Ps*xs)/Mh;

    % Each tow is drawn in all four quadrants, NaN-separated so one plot call can draw all
    segx = @(a) [a(:); NaN; -a(:); NaN; a(:); NaN; -a(:); NaN];
    segy = @(b) [b(:); NaN; b(:); NaN; -b(:); NaN; -b(:); NaN];
    XS = [];  YS = [];
    TW = [];                                        % tow centre lines, one row [x1 y1 x2 y2] each

    % Outer line sequence
    x = [0, W/2, 0, W/2 - f + Ps*xs, W/2 - cs];
    y = [L/2 + d + (Ps*ys), L/2 + d + (Ps*ys), L/4 + d + (Ps*ys), 0, L/2 + d + (Ps*ys - cs)];
    XS = [XS; segx(x)];  YS = [YS; segy(y + Er)];

    % Outer line from top to bottom
    x1 = [W/2, W/2 - f];
    y1 = [L/2 + d + (Ps*ys), (Ps*ys)];
    XS = [XS; segx(x1)];  YS = [YS; segy(y1 + Er)];

    % Straight line showing the middle part of the specimen
    x2 = [W/2 - f + Ps*xs, W/2 - f + Ps*xs];
    y2 = [Er, 0];
    XS = [XS; segx(x2)];  YS = [YS; segy(y2)];

    % Downwards tows, right-triangular region (/ direction a-c)
    for P = 0:N
        a1 = [W/2 - cs - P*L9, P*L7];
        b1 = [L/2 + d + (Ps*ys - cs) - P*L10, L/4 + d + (Ps*ys) - P*L8];
        TW = [TW; towRow_wov(a1, b1 + Er, P)];
    end

    % Upwards tows, right-triangular region (\ direction a-b)
    for P = 0:N
        a2 = [W/2 - P*L4*sin(t1), W/2 - P*L2*cos(t3)];
        b2 = [L/2 + d - P*L4*cos(t1) + (Ps*ys), L/2 + d - P*L2*sin(t3) + (Ps*ys)];
        TW = [TW; towRow_wov(a2, b2 + Er, P)];
    end

    % Bottom half tows, centre region (/ direction c-e)
    for P = 0:Mh
        Q = P + Mh;
        a3 = [Q*L7, P*L11];
        b3 = [L/4 + d + (Ps*ys) - Q*L8, 0];
        TW = [TW; towRow_wov(a3, b3 + Er, P)];
    end

    % Top half tows, centre region (/ direction c-g)
    for P = 0:Mh
        Q = Mh - P;
        a4 = [P*L7, 0];
        b4 = [L/4 + d + (Ps*ys) - P*L8, Q*L12];
        TW = [TW; towRow_wov(a4, b4 + Er, P)];
    end

    % Vertical to horizontal tows, centre region (\ direction e-g)
    for P = 0:Mh
        a5 = [P*L11, 0];
        b5 = [0, P*L12];
        TW = [TW; towRow_wov(a5, b5 + Er, P)];
    end

    % Bottom half tows, upper-triangular region (\ direction b-f)
    for P = (N+1)/2:(N+1)
        Q = (N+1) - P;
        a6 = [W/2 - P*L2*cos(t3), 0];
        b6 = [L/2 + d - P*L2*sin(t3) + Ps*ys, L/4 + d + Q*L13 + Ps*ys];
        TW = [TW; towRow_wov(a6, b6 + Er, P)];
    end

    % Top half tows, upper-triangular region (\ direction b-d)
    for P = 0:(N+1)/2
        a7 = [W/2 - P*L2*cos(t3), W/2 - P*L14];
        b7 = [L/2 + d - P*L2*sin(t3) + Ps*ys, L/2 + d + Ps*ys];
        TW = [TW; towRow_wov(a7, b7 + Er, P)];
    end

    % Tows, upper-triangular region (/ direction d-f)
    for P = 0:(N+1)/2
        a8 = [W/2 - P*L14, 0];
        b8 = [L/2 + d + Ps*ys, L/4 + d + P*L13 + Ps*ys];
        TW = [TW; towRow_wov(a8, b8 + Er, P)];
    end

    % Tows for ratio of more than 2
    for P = 0:Mh
        Q1 = Mv - P;
        if Q1 <= 0
            break
        end

        U = [W/2 - f + Ps*xs, W/2 - f + Ps*xs - P*Z2];
        V = [Er - P*Z1, Er];
        TW = [TW; towRow_wov(U, V, P)];

        U1 = [0, P*Z2];
        V1 = [Er - P*Z1, Er];
        TW = [TW; towRow_wov(U1, V1, P)];

        U2 = [W/2 - f + Ps*xs, W/2 - f + Ps*xs - P*Z2];
        V2 = [P*Z1, 0];
        TW = [TW; towRow_wov(U2, V2, P)];

        U3 = [0, P*Z2];
        V3 = [P*Z1, 0];
        TW = [TW; towRow_wov(U3, V3, P)];
    end

    % Cross-lines for ratio above 2.5
    for P = 0:(Mv - Mh)
        Q2 = Mv - P;
        if Q2 <= 0
            break
        end

        U4 = [W/2 - f + Ps*xs, 0];
        V4 = [Er - P*Z1, Er - (Mh*Z1) - P*Z1];
        TW = [TW; towRow_wov(U4, V4, P)];

        U5 = [0, W/2 - f + Ps*xs];
        V5 = [Er - P*Z1, Er - (Mh*Z1) - P*Z1];
        TW = [TW; towRow_wov(U5, V5, P)];
    end

    % Diagonal tows for the remaining ratios (the original only skips this for R1 = 2 or R1 > 2.5)
    G2 = (W/2 - f + Ps*xs)/(2*Z2);
    for P = 0:Mh - G2
        Q = Mh - G2 - P;
        if R1 == 2 || R1 > 2.5
            break
        end

        U6 = [P*Z2, W/2 - f + Ps*xs - Q*Z2];
        V6 = [0, Er];
        TW = [TW; towRow_wov(U6, V6, P)];

        U7 = [P*Z2, W/2 - f + Ps*xs - Q*Z2];
        V7 = [Er, 0];
        TW = [TW; towRow_wov(U7, V7, P)];
    end

    % Mirror the tow centre lines into the four quadrants (columns: x1 y1 x2 y2 tag)
    TWm = [TW; TW.*[-1 1 -1 1 1]; TW.*[1 -1 1 -1 1]; TW.*[-1 -1 -1 -1 1]];
    segLen = hypot(TWm(:,3) - TWm(:,1), TWm(:,4) - TWm(:,2));
    TWm = TWm(segLen > 1e-6, :);                    % drop zero-length segments

    % Give every segment the same direction and drop exact duplicates (mirrored copies can
    % coincide), so no crossing is counted twice; the first copy keeps its tag
    swap = TWm(:,1) > TWm(:,3) | (TWm(:,1) == TWm(:,3) & TWm(:,2) > TWm(:,4));
    TWm(swap, :) = TWm(swap, [3 4 1 2 5]);
    [~, keep] = unique(round(TWm(:,1:4)*1e4), 'rows', 'stable');
    TWm = TWm(keep, :);

    % Specimen length, and optionally hold the bottom at y = 0 so only the top moves
    % (the whole drawing is shifted up by its half-length, so the top moves at the full rate)
    allY = [YS; TWm(:,2); TWm(:,4)];
    fr.Ltot = max(allY) - min(allY);
    if p.FixBottom
        yShift = min(allY);
        YS = YS - yShift;
        TWm(:, [2 4]) = TWm(:, [2 4]) - yShift;
    end

    % Tow width: constant physical width, 'auto' = tow spacing in the unsheared centre region
    towW = p.TowW;
    if isnan(towW)
        towW = Li/(N+1);
    end
    fr.TowW = towW;

    if p.Bands
        B = towBands_wov(TWm, towW/2, p.Weave, p.NStrips);
        names = fieldnames(B);
        for kf = 1:numel(names)
            fr.(names{kf}) = B.(names{kf});
        end
    else
        % Original thin-line drawing: add the tow centre lines to the line data
        fr.ShadeAX = repmat({NaN(4,1)}, 1, p.NStrips);  fr.ShadeAY = repmat({NaN(4,1)}, 1, p.NStrips);
        fr.ShadeBX = repmat({NaN(4,1)}, 1, p.NStrips);  fr.ShadeBY = repmat({NaN(4,1)}, 1, p.NStrips);
        fr.ShadeAA = zeros(1, p.NStrips);  fr.ShadeBA = zeros(1, p.NStrips);
        fr.XA = NaN(4,1);  fr.YA = NaN(4,1);
        fr.XB = NaN(4,1);  fr.YB = NaN(4,1);
        fr.EAx = NaN;  fr.EAy = NaN;  fr.EBx = NaN;  fr.EBy = NaN;
        fr.OX = NaN(4,1);  fr.OY = NaN(4,1);  fr.OEx = NaN;  fr.OEy = NaN;
        nT = size(TWm, 1);
        XL = [TWm(:,1), TWm(:,3), NaN(nT,1)].';
        YL = [TWm(:,2), TWm(:,4), NaN(nT,1)].';
        XS = [XS; XL(:)];
        YS = [YS; YL(:)];
    end
    fr.XS = XS;
    fr.YS = YS;
end


function r = towRow_wov(a, b, P)
% TOWROW  One tow centre line from its two x values (a) and two y values (b), tagged with the
% tow's number P within its group. The tag gives the weave a stable over/under pattern.
    r = [a(1), b(1), a(2), b(2), round(P)];
end


function B = towBands_wov(T, hw, doWeave, N_STRIPS_SH)
% TOWBANDS  Turn tow centre lines (rows [x1 y1 x2 y2 tag]) into bands of half-width hw.
% B.XA,YA / B.XB,YB     : 4-row polygon matrices for the "/" tows (A) and the "\" tows (B)
% B.EAx,EAy / B.EBx,EBy : NaN-separated long sides of those bands (the cut ends are not outlined)
% B.OX,OY / B.OEx,OEy   : with doWeave, the crossings where a "/" tow passes over a "\" tow
    dx  = T(:,3) - T(:,1);
    dy  = T(:,4) - T(:,2);
    len = hypot(dx, dy);
    nx  = -dy./len*hw;                              % half-width offset, perpendicular to the tow
    ny  =  dx./len*hw;
    XQ = [T(:,1)+nx, T(:,3)+nx, T(:,3)-nx, T(:,1)-nx].';   % 4 x n, corners go clockwise
    YQ = [T(:,2)+ny, T(:,4)+ny, T(:,4)-ny, T(:,2)-ny].';
    isA = (dx.*dy) >= 0;                            % rising ("/") tows
    B.XA = XQ(:, isA);   B.YA = YQ(:, isA);
    B.XB = XQ(:, ~isA);  B.YB = YQ(:, ~isA);
    if isempty(B.XA), B.XA = NaN(4,1); B.YA = NaN(4,1); end
    if isempty(B.XB), B.XB = NaN(4,1); B.YB = NaN(4,1); end

    % Outline only the two long sides of each band (corner 1 -> 2 and corner 4 -> 3), not the ends
    edg = @(Q) reshape([Q(1,:); Q(2,:); NaN(1, size(Q,2)); Q(4,:); Q(3,:); NaN(1, size(Q,2))], [], 1);
    B.EAx = edg(B.XA);  B.EAy = edg(B.YA);
    B.EBx = edg(B.XB);  B.EBy = edg(B.YB);

    B.OX = NaN(4,1);  B.OY = NaN(4,1);  B.OEx = NaN;  B.OEy = NaN;
    if doWeave && any(isA) && any(~isA)
        [B.OX, B.OY, B.OEx, B.OEy] = weaveOver(T, XQ, YQ, isA, hw);
    end

    % Shading strips: N_STRIPS_SH thin quads per tow, computed separately for each
    % tow direction so their opposite normals don't cancel each other out.
    % "/" (A) tows and "\" (B) tows each get their own ShadeX/Y/A arrays.
    % drawAt applies the same white/black overlay pass to both.
    LX_sh = -0.6;  LY_sh = 0.8;
    HILIGHT_SH = 0.30;  SHADOW_SH = 0.24;

    dx_sh  = T(:,3) - T(:,1);  dy_sh  = T(:,4) - T(:,2);
    len_sh = hypot(dx_sh, dy_sh);
    nxU_sh = -dy_sh./len_sh;   nyU_sh =  dx_sh./len_sh;
    dotL   = nxU_sh*LX_sh + nyU_sh*LY_sh;   % per-tow dot with light, in [-1,1]

    % Mean dot per direction (all tows in one direction are parallel, so this is stable)
    dotA_sh = mean(dotL(isA));
    dotB_sh = mean(dotL(~isA));

    tEdge_sh = linspace(-hw, hw, N_STRIPS_SH+1);
    tMid_sh  = (tEdge_sh(1:end-1) + tEdge_sh(2:end)) / 2;  % normalised strip centre

    TA_sh = T(isA,:);   nxA_sh = nxU_sh(isA);  nyA_sh = nyU_sh(isA);
    TB_sh = T(~isA,:);  nxB_sh = nxU_sh(~isA); nyB_sh = nyU_sh(~isA);

    B.ShadeAX = cell(1, N_STRIPS_SH);  B.ShadeAY = cell(1, N_STRIPS_SH);
    B.ShadeBX = cell(1, N_STRIPS_SH);  B.ShadeBY = cell(1, N_STRIPS_SH);
    B.ShadeAA = zeros(1, N_STRIPS_SH);  % alpha per strip for "/" tows
    B.ShadeBA = zeros(1, N_STRIPS_SH);  % alpha per strip for "\" tows

    for s_sh = 1:N_STRIPS_SH
        t0_sh = tEdge_sh(s_sh);  t1_sh = tEdge_sh(s_sh+1);
        normPos = tMid_sh(s_sh) / hw;   % in [-1, +1], position across tow width

        % "/" tows
        if ~isempty(TA_sh)
            B.ShadeAX{s_sh} = [TA_sh(:,1)+nxA_sh*t0_sh, TA_sh(:,3)+nxA_sh*t0_sh, ...
                                TA_sh(:,3)+nxA_sh*t1_sh, TA_sh(:,1)+nxA_sh*t1_sh].';
            B.ShadeAY{s_sh} = [TA_sh(:,2)+nyA_sh*t0_sh, TA_sh(:,4)+nyA_sh*t0_sh, ...
                                TA_sh(:,4)+nyA_sh*t1_sh, TA_sh(:,2)+nyA_sh*t1_sh].';
        else
            B.ShadeAX{s_sh} = NaN(4,1);  B.ShadeAY{s_sh} = NaN(4,1);
        end
        alignA = normPos * dotA_sh;   % +1 when strip is on lit side of "/" tows
        B.ShadeAA(s_sh) = alignA * (alignA > 0)*HILIGHT_SH + alignA * (alignA < 0)*SHADOW_SH;

        % "\" tows
        if ~isempty(TB_sh)
            B.ShadeBX{s_sh} = [TB_sh(:,1)+nxB_sh*t0_sh, TB_sh(:,3)+nxB_sh*t0_sh, ...
                                TB_sh(:,3)+nxB_sh*t1_sh, TB_sh(:,1)+nxB_sh*t1_sh].';
            B.ShadeBY{s_sh} = [TB_sh(:,2)+nyB_sh*t0_sh, TB_sh(:,4)+nyB_sh*t0_sh, ...
                                TB_sh(:,4)+nyB_sh*t1_sh, TB_sh(:,2)+nyB_sh*t1_sh].';
        else
            B.ShadeBX{s_sh} = NaN(4,1);  B.ShadeBY{s_sh} = NaN(4,1);
        end
        alignB = normPos * dotB_sh;
        B.ShadeBA(s_sh) = alignB * (alignB > 0)*HILIGHT_SH + alignB * (alignB < 0)*SHADOW_SH;
    end
end


function [OX, OY, OEx, OEy] = weaveOver(T, XQ, YQ, isA, hw)
% WEAVEOVER  Plain-weave interlacing. Every place where a "/" tow crosses a "\" tow is a
% crossing, and neighbouring crossings along any tow alternate (over, under, over, ...).
% Where the "/" tow is on top, the overlap of the two bands is painted again in the "/"
% colour (and the "/" tow's long sides are redrawn), which hides the "\" tow there.
    OX = NaN(4,1);  OY = NaN(4,1);  OEx = NaN;  OEy = NaN;
    iA = find(isA);  iB = find(~isA);
    [ia, ib, ta, tb] = crossPairs(T(iA,:), T(iB,:));
    if isempty(ia), return; end
    gA = iA(ia);  gB = iB(ib);                      % rows of T for each crossing pair
    px = T(gA,1) + ta.*(T(gA,3) - T(gA,1));         % crossing position
    py = T(gA,2) + ta.*(T(gA,4) - T(gA,2));
    aOver = weaveColours(ia, ib, ta, tb, numel(iA), numel(iB), px, py, T(gA,5) + T(gB,5));
    pairs = find(aOver);
    nO = numel(pairs);
    if nO == 0, return; end

    OX = NaN(8, nO);  OY = NaN(8, nO);              % one overlap polygon per column (<= 8 corners)
    EX = NaN(3, 8*nO);  EY = NaN(3, 8*nO);
    nE = 0;
    for kk = 1:nO
        k = pairs(kk);
        a = gA(k);  b = gB(k);
        poly = clipConvex([XQ(:,b), YQ(:,b)], [XQ(:,a), YQ(:,a)]);   % overlap of the two bands
        m = size(poly, 1);
        if m < 3, continue; end
        OX(:,kk) = [poly(:,1); repmat(poly(m,1), 8-m, 1)];
        OY(:,kk) = [poly(:,2); repmat(poly(m,2), 8-m, 1)];

        % Outline only the sides that lie on the long sides of the "/" tow
        la  = hypot(T(a,3) - T(a,1), T(a,4) - T(a,2));
        nxa = -(T(a,4) - T(a,2))/la;                % unit normal of the "/" tow
        nya =  (T(a,3) - T(a,1))/la;
        for i = 1:m
            j  = mod(i, m) + 1;
            ex = poly(j,1) - poly(i,1);  ey = poly(j,2) - poly(i,2);
            le = hypot(ex, ey);
            if le > 1e-6 && abs(ex*nxa + ey*nya)/le < 1e-6      % parallel to the tow
                mx = (poly(i,1) + poly(j,1))/2 - T(a,1);
                my = (poly(i,2) + poly(j,2))/2 - T(a,2);
                if abs(abs(mx*nxa + my*nya) - hw) < 1e-6        % and on its edge, not inside it
                    nE = nE + 1;
                    EX(1:2, nE) = [poly(i,1); poly(j,1)];
                    EY(1:2, nE) = [poly(i,2); poly(j,2)];
                end
            end
        end
    end
    if nE > 0
        OEx = reshape(EX(:, 1:nE), [], 1);
        OEy = reshape(EY(:, 1:nE), [], 1);
    end
end


function [ia, ib, ta, tb] = crossPairs(TA, TB)
% CROSSPAIRS  All pairs of "/" and "\" tow centre lines that cross or touch end to end.
% ia, ib : row numbers in TA and TB;  ta, tb : position along each line (0 = start, 1 = end)
    nA = size(TA, 1);  nB = size(TB, 1);
    RX = repmat(TA(:,3) - TA(:,1), 1, nB);   RY = repmat(TA(:,4) - TA(:,2), 1, nB);
    SX = repmat((TB(:,3) - TB(:,1)).', nA, 1);  SY = repmat((TB(:,4) - TB(:,2)).', nA, 1);
    QX = repmat(TB(:,1).', nA, 1) - repmat(TA(:,1), 1, nB);
    QY = repmat(TB(:,2).', nA, 1) - repmat(TA(:,2), 1, nB);
    den = RX.*SY - RY.*SX;
    t = (QX.*SY - QY.*SX)./den;
    u = (QX.*RY - QY.*RX)./den;
    tol = 1e-6;                                     % end-to-end contacts count as crossings
    ok = abs(den) > 1e-9 & t >= -tol & t <= 1+tol & u >= -tol & u <= 1+tol;
    [ia, ib] = find(ok);
    ta = t(ok);
    tb = u(ok);
end


function aOver = weaveColours(ia, ib, ta, tb, nA, nB, px, py, tagSum)
% WEAVECOLOURS  Decide, for every crossing pair, whether the "/" tow is on top.
% Crossings at the same place (tows meeting end to end) form one node. Neighbouring nodes along
% a tow get opposite answers, which is what makes it a plain weave. Each connected group of
% nodes is then flipped, if needed, to agree with the tow numbering (tagSum), so the pattern is
% the same in every frame.
    key = round([px, py]*100);                      % nodes closer than 0.01 mm are the same node
    [~, first, nodeOf] = unique(key, 'rows', 'first');
    nodeOf = nodeOf(:);
    nN = numel(first);
    formula = mod(tagSum(first), 2);

    E = zeros(0, 2);                                % neighbouring nodes along each tow
    for k = 1:nA
        idx = find(ia == k);
        if numel(idx) > 1
            [~, o] = sort(ta(idx));
            nn = nodeOf(idx(o));
            E = [E; nn(1:end-1), nn(2:end)];        %#ok<AGROW>
        end
    end
    for k = 1:nB
        idx = find(ib == k);
        if numel(idx) > 1
            [~, o] = sort(tb(idx));
            nn = nodeOf(idx(o));
            E = [E; nn(1:end-1), nn(2:end)];        %#ok<AGROW>
        end
    end
    E = E(E(:,1) ~= E(:,2), :);
    if isempty(E)
        Adj = sparse(nN, nN);
    else
        Adj = sparse([E(:,1); E(:,2)], [E(:,2); E(:,1)], 1, nN, nN);
    end

    colr = -ones(nN, 1);                            % 0 = "/" over, 1 = "\" over
    for s0 = 1:nN
        if colr(s0) >= 0, continue; end
        colr(s0) = 0;
        queue = s0;  comp = s0;  qh = 1;
        while qh <= numel(queue)
            c = queue(qh);  qh = qh + 1;
            nb = find(Adj(:, c));
            for q = nb.'
                if colr(q) < 0
                    colr(q) = 1 - colr(c);
                    queue(end+1) = q;               %#ok<AGROW>
                    comp(end+1) = q;                %#ok<AGROW>
                end
            end
        end
        if mean(colr(comp) == formula(comp)) < 0.5
            colr(comp) = 1 - colr(comp);
        end
    end
    aOver = colr(nodeOf) == 0;
end


function poly = clipConvex(poly, clip)
% CLIPCONVEX  Overlap of two convex polygons (n-by-2 corner lists, both clockwise):
% Sutherland-Hodgman clipping of poly by each side of clip.
    nc = size(clip, 1);
    for e = 1:nc
        if isempty(poly), return; end
        c1 = clip(e, :);
        c2 = clip(mod(e, nc) + 1, :);
        ex = c2(1) - c1(1);  ey = c2(2) - c1(2);
        s = ex*(poly(:,2) - c1(2)) - ey*(poly(:,1) - c1(1));   % <= 0 means inside (right of the side)
        inside = s <= 1e-9;
        n = size(poly, 1);
        out = zeros(2*n, 2);
        m = 0;
        for i = 1:n
            j = mod(i, n) + 1;
            if inside(i)
                m = m + 1;
                out(m, :) = poly(i, :);
            end
            if inside(i) ~= inside(j)
                t = s(i)/(s(i) - s(j));
                m = m + 1;
                out(m, :) = poly(i, :) + t*(poly(j, :) - poly(i, :));
            end
        end
        poly = out(1:m, :);
    end
end
