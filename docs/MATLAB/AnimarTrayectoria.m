function AnimarTrayectoria(TrayArt, L1, L2, Tiempos, SpeedUp_Factor, smooth_window, cut_z_threshold)
% ANIMARTRAYECTORIA - Animacion del robot SCARA P-R-R en 3D con tiempos reales.
% TrayArt: Nx5 [d1 th2 th3 flag V]
% FLAGS: 1=corte, 2/3=traslado.

    if nargin < 4, error('Falta el vector de Tiempos para la animacion.'); end
    if nargin < 5, SpeedUp_Factor = 1; end
    if nargin < 6, smooth_window = 0; end
    % Si no se entrega umbral, asumimos 0.26 m como altura de no corte (lift)
    if nargin < 7 || isempty(cut_z_threshold)
        cut_z_threshold = 0.26; 
    end
    if isempty(TrayArt), return; end

    % Copia para visualizacion con suavizado opcional (no altera los datos de control)
    TrayArt_plot = TrayArt;
    if smooth_window > 1
        win = max(3, 2 * floor(smooth_window / 2) + 1); % ventana impar
        for k = 1:3
            TrayArt_plot(:, k) = smoothdata(TrayArt_plot(:, k), 'movmedian', win);
        end
    end

    % --- Configuracion inicial
    [ax, handles] = configurarEscena(SpeedUp_Factor);
    handles.h_tray_corte = plot3(ax, NaN, NaN, NaN, 'y-', 'LineWidth', 1.5, 'DisplayName', 'Corte (Trabajo)');
    % Color visible sobre fondo claro (cyan) y linea mas gruesa
    handles.h_tray_traslado = plot3(ax, NaN, NaN, NaN, 'c--', 'LineWidth', 1.5, 'DisplayName', 'Traslado (Rapido)');

    num_puntos = size(TrayArt_plot, 1);
    Fs_simulacion = 500;
    Fs_dibujo_deseado = 25;
    skip_rate = max(1, floor(Fs_simulacion / Fs_dibujo_deseado));
    fprintf('Muestreo activo: dibujando 1 de cada %.0f puntos (Target Fs: %.0f Hz). Pausa real/%.0f.\n', skip_rate, Fs_simulacion/skip_rate, SpeedUp_Factor);

    T_anterior_dibujo = Tiempos(1);
    Trayectoria_Corte = [];
    Trayectoria_Traslado = [];
    flag_anterior = TrayArt(1, 4);
    P_base_z0 = [0; 0; 0];

    % --- Bucle principal
    for i = 1:num_puntos
        if any(isnan(TrayArt_plot(i, 1:3))), continue; end
        if mod(i, skip_rate) ~= 0 && i ~= num_puntos, continue; end

        T_actual = Tiempos(i);
        dt_real = T_actual - T_anterior_dibujo;
        pause_duration = dt_real / SpeedUp_Factor;
        if ~isfinite(pause_duration) || pause_duration < 0
            pause_duration = 1e-9;
        end

        Q_Art = TrayArt_plot(i, 1:3); % [d1 th2 th3]
        flag_corte = TrayArt(i, 4);
        % Reinterpretar como traslado visual si Z supera umbral (lift) aunque flag sea 1
        if Q_Art(1) > cut_z_threshold
            flag_visual = 3;
        else
            flag_visual = flag_corte;
        end

        pos = calcularPosiciones(Q_Art, L1, L2);
        handles = inicializarRobotSiNecesario(ax, handles, P_base_z0, pos);

        % Acumular trayectorias segun flag
        if flag_visual == 1
            if flag_anterior >= 2 && ~isempty(Trayectoria_Corte)
                Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]];
            end
            Trayectoria_Corte = [Trayectoria_Corte; pos.mano_fila];
            if flag_anterior >= 2
                Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]];
            end
            set(handles.h_efector_final, 'XData', pos.X, 'YData', pos.Y, 'ZData', pos.Z);
        elseif flag_visual >= 2
            if flag_anterior == 1 && ~isempty(Trayectoria_Traslado)
                Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]];
            end
            Trayectoria_Traslado = [Trayectoria_Traslado; pos.mano_fila];
            if flag_anterior == 1
                Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]];
            end
            set(handles.h_efector_final, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end
        flag_anterior = flag_visual;

        % Actualizar geometria del robot
        set(handles.h_prism, 'ZData', [P_base_z0(3) pos.base_z1(3)]);
        set(handles.h_brazo1, 'XData', [pos.base_z1(1) pos.codo(1)], 'YData', [pos.base_z1(2) pos.codo(2)], 'ZData', [pos.base_z1(3) pos.codo(3)]);
        set(handles.h_brazo2, 'XData', [pos.codo(1) pos.mano_col(1)], 'YData', [pos.codo(2) pos.mano_col(2)], 'ZData', [pos.codo(3) pos.mano_col(3)]);

        if ~isempty(Trayectoria_Corte)
            set(handles.h_tray_corte, 'XData', Trayectoria_Corte(:,1), 'YData', Trayectoria_Corte(:,2), 'ZData', Trayectoria_Corte(:,3));
        end
        if ~isempty(Trayectoria_Traslado)
            set(handles.h_tray_traslado, 'XData', Trayectoria_Traslado(:,1), 'YData', Trayectoria_Traslado(:,2), 'ZData', Trayectoria_Traslado(:,3));
        end

        drawnow limitrate;
        pause(pause_duration);
        T_anterior_dibujo = T_actual;
    end

    fprintf('Animacion finalizada. Velocidad visual fiel al perfil trapezoidal (x%.0f).\n', SpeedUp_Factor);
end

% -------------------------------------------------------------------------
function [ax, handles] = configurarEscena(SpeedUp_Factor)
    set(groot,'defaultTextInterpreter','none');
    set(groot,'defaultAxesTickLabelInterpreter','none');
    set(groot,'defaultLegendInterpreter','none');

    figureName = sprintf('Simulacion de Trayectoria SCARA P-R-R (Visualizacion %.0fx)', SpeedUp_Factor);
    h_fig = figure('Name', figureName, 'Position', [100 100 800 600]);
    ax = axes('Parent', h_fig);

    hold(ax,'on'); grid(ax,'on'); axis equal;
    xlim(ax, [-0.3, 1]); ylim(ax, [-0.3, 1]); zlim(ax, [0, 0.3]);
    xlabel('Eje X (m)'); ylabel('Eje Y (m)'); zlabel('Eje Z (m)');
    title(sprintf('Validacion Dinamica SCARA-CNC (P-R-R). Factor %.0fx.', SpeedUp_Factor));
    view(ax, 45, 30);

    handles = struct();
end

function pos = calcularPosiciones(Q_Art, L1, L2)
    P_cart = CinematicaDirecta(Q_Art, L1, L2);
    pos.X = P_cart(1);
    pos.Y = P_cart(2);
    pos.Z = P_cart(3);
    pos.cart = P_cart;
    pos.base_z1 = [0; 0; pos.Z];
    pos.codo = [L1*cos(Q_Art(2)); L1*sin(Q_Art(2)); pos.Z];
    pos.mano_col = [pos.X; pos.Y; pos.Z];
    pos.mano_fila = P_cart;
end

function handles = inicializarRobotSiNecesario(ax, handles, P_base_z0, pos)
    if isfield(handles, 'h_prism')
        return;
    end
    handles.h_prism = plot3(ax, [P_base_z0(1) pos.base_z1(1)], [P_base_z0(2) pos.base_z1(2)], [P_base_z0(3) pos.base_z1(3)], ...
        'Color', [0.5 0.5 0.5], 'LineWidth', 6, 'LineStyle', '-', 'DisplayName', 'Articulacion 1 (d1, prismatica)');
    handles.h_brazo1 = plot3(ax, [pos.base_z1(1) pos.codo(1)], [pos.base_z1(2) pos.codo(2)], [pos.base_z1(3) pos.codo(3)], ...
        '-', 'LineWidth', 4, 'Color', [0 0 1], 'MarkerSize', 8, 'DisplayName', 'Articulacion 2 (th2, rotativa)');
    handles.h_brazo2 = plot3(ax, [pos.codo(1) pos.mano_col(1)], [pos.codo(2) pos.mano_col(2)], [pos.codo(3) pos.mano_col(3)], ...
        '-', 'LineWidth', 4, 'Color', [0 1 0], 'MarkerSize', 8, 'DisplayName', 'Articulacion 3 (th3, rotativa)');
    handles.h_efector_final = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r', 'HandleVisibility', 'off', 'DisplayName', 'Efector final');
    legend(ax, [handles.h_tray_corte, handles.h_tray_traslado, handles.h_prism, handles.h_brazo1, handles.h_brazo2], ...
        {'Corte (Trabajo)', 'Traslado (Rapido)', 'Articulacion 1 (d1, prismatica)', 'Articulacion 2 (th2, rotativa)', 'Articulacion 3 (th3, rotativa)'}, ...
        'Location', 'best');
end
