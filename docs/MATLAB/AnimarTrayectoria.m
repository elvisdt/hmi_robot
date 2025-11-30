function AnimarTrayectoria(TrayArt, L1, L2, Tiempos, SpeedUp_Factor)
% ANIMARTRAYECTORIA - Animacion del robot SCARA P-R-R en 3D con tiempos reales.
% TrayArt: Nx5 [d1 th2 th3 flag V]
% FLAGS: 1=corte, 2/3=traslado.

    if nargin < 4, error('Falta el vector de Tiempos para la animacion.'); end
    if nargin < 5, SpeedUp_Factor = 1; end

    % Desactivar interpretes LaTeX para evitar warnings
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
    num_puntos = size(TrayArt, 1);

    Fs_simulacion = 500;
    Fs_dibujo_deseado = 25;
    skip_rate = max(1, floor(Fs_simulacion / Fs_dibujo_deseado));
    fprintf('Muestreo activo: dibujando 1 de cada %.0f puntos (Target Fs: %.0f Hz). Pausa real/%.0f.\n', skip_rate, Fs_simulacion/skip_rate, SpeedUp_Factor);

    T_anterior_dibujo = Tiempos(1);

    handles.h_tray_corte = plot3(ax, NaN, NaN, NaN, 'y-', 'LineWidth', 1.5, 'DisplayName', 'Corte (Trabajo)');
    handles.h_tray_traslado = plot3(ax, NaN, NaN, NaN, 'w--', 'LineWidth', 1, 'DisplayName', 'Traslado (Rapido)');

    Trayectoria_Corte = [];
    Trayectoria_Traslado = [];
    flag_anterior = TrayArt(1, 4);

    for i = 1:num_puntos
        if any(isnan(TrayArt(i, 1:3))), continue; end

        if mod(i, skip_rate) == 0 || i == num_puntos
            T_actual = Tiempos(i);
            dt_real = T_actual - T_anterior_dibujo;
            pause_duration = dt_real / SpeedUp_Factor;
            if ~isfinite(pause_duration) || pause_duration < 0
                pause_duration = 1e-9;
            end

            Q_Art = TrayArt(i, 1:3); % [d1 th2 th3]
            flag_corte = TrayArt(i, 4);

            P_cart = CinematicaDirecta(Q_Art, L1, L2);
            X = P_cart(1); Y = P_cart(2); Z = P_cart(3);

            P_base_z0 = [0; 0; 0];
            P_base_z1 = [0; 0; Z];
            P_codo = [L1*cos(Q_Art(2)); L1*sin(Q_Art(2)); Z];
            P_mano_col = [X; Y; Z];
            P_mano_fila = P_cart;

            if ~isfield(handles, 'h_prism')
                handles.h_prism = plot3(ax, [P_base_z0(1) P_base_z1(1)], [P_base_z0(2) P_base_z1(2)], [P_base_z0(3) P_base_z1(3)], 'Color', [0.5 0.5 0.5], 'LineWidth', 6, 'LineStyle', '-');
                handles.h_brazo1 = plot3(ax, [P_base_z1(1) P_codo(1)], [P_base_z1(2) P_codo(2)], [P_base_z1(3) P_codo(3)], '-', 'LineWidth', 4, 'Color', [0 0 1], 'MarkerSize', 8);
                handles.h_brazo2 = plot3(ax, [P_codo(1) P_mano_col(1)], [P_codo(2) P_mano_col(2)], [P_codo(3) P_mano_col(3)], '-', 'LineWidth', 4, 'Color', [0 1 0], 'MarkerSize', 8);
                handles.h_efector_final = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r', 'HandleVisibility', 'off');
                legend(ax, 'show', 'Location', 'best');
            end

            if flag_corte == 1
                if flag_anterior >= 2 && ~isempty(Trayectoria_Corte)
                    Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]];
                end
                Trayectoria_Corte = [Trayectoria_Corte; P_mano_fila];
                if flag_anterior >= 2
                    Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]];
                end
                set(handles.h_efector_final, 'XData', X, 'YData', Y, 'ZData', Z);
            elseif flag_corte >= 2
                if flag_anterior == 1 && ~isempty(Trayectoria_Traslado)
                    Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]];
                end
                Trayectoria_Traslado = [Trayectoria_Traslado; P_mano_fila];
                if flag_anterior == 1
                    Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]];
                end
                set(handles.h_efector_final, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            end

            flag_anterior = flag_corte;

            set(handles.h_prism, 'ZData', [P_base_z0(3) P_base_z1(3)]);
            set(handles.h_brazo1, 'XData', [P_base_z1(1) P_codo(1)], 'YData', [P_base_z1(2) P_codo(2)], 'ZData', [P_base_z1(3) P_codo(3)]);
            set(handles.h_brazo2, 'XData', [P_codo(1) P_mano_col(1)], 'YData', [P_codo(2) P_mano_col(2)], 'ZData', [P_codo(3) P_mano_col(3)]);

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
    end

    fprintf('Animacion finalizada. Velocidad visual fiel al perfil trapezoidal (x%.0f).\n', SpeedUp_Factor);
end
