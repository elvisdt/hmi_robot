function AnimarTrayectoria(TrayArt, L1, L2, Tiempos, SpeedUp_Factor, smooth_window, cut_z_threshold)
% ANIMARTRAYECTORIA - Anima el robot SCARA P-R-R en 3D, respetando la trayectoria 3D completa
%                     y PAUSA BASADA EN EL TIEMPO REAL (Tiempos).

    % --- VERIFICACION DE ENTRADAS ---
    if nargin < 4, error('Falta el vector de Tiempos para la animacion.'); end
    if nargin < 5, SpeedUp_Factor = 1; end
    if nargin < 6, smooth_window = 0; end
    if nargin < 7 || isempty(cut_z_threshold), cut_z_threshold = 0.26; end % altura no corte (m)
    if isempty(TrayArt), return; end

    % Copia para visualizacion con suavizado opcional (no altera datos de control)
    TrayArt_plot = TrayArt;
    if smooth_window > 1
        win = max(3, 2 * floor(smooth_window / 2) + 1); % ventana impar
        for k = 1:3
            TrayArt_plot(:, k) = smoothdata(TrayArt_plot(:, k), 'movmedian', win);
        end
    end
    
    % --- INICIALIZACION DE LA FIGURA Y HANDLES ---
    figureName = sprintf('Simulacion de Trayectoria SCARA P-R-R (Visualizacion %.0fx)', SpeedUp_Factor);
    h_fig = figure('Name', figureName, 'Position', [100 100 800 600]);
    ax = axes('Parent', h_fig);
    
    hold(ax,'on'); grid(ax,'on'); axis equal;
    % Ajuste de limites basado en el workspace maximo del SCARA: L1+L2 = 1.25 m
    xlim(ax, [-0.3, 1]); ylim(ax, [-0.3, 1]); zlim(ax, [0, 0.4]); 
    xlabel('Eje X (m)'); ylabel('Eje Y (m)'); zlabel('Eje Z (m)');
    title(sprintf('Validacion Dinamica SCARA-CNC (P-R-R). Fiel a Tiempos Reales (Factor %.0fx).', SpeedUp_Factor));
    
    view(ax, 45, 30); % Establece una vista 3D
    
    handles = struct(); 
    
    % --- Loop Principal Unico sobre toda la Trayectoria ---
    num_puntos = size(TrayArt, 1);
    
    % ***************************************************************
    % CORRECCION DEL SKIP_RATE
    Fs_simulacion = 500; 
    Fs_dibujo_deseado = 25; 
    skip_rate = max(1, floor(Fs_simulacion / Fs_dibujo_deseado)); 
    % ***************************************************************
    fprintf('    Muestreo Activo: Dibujando 1 de cada %.0f puntos (Target Fs: %.0f Hz). Pausa basada en Tiempos Reales / %.0f.\n', skip_rate, Fs_simulacion/skip_rate, SpeedUp_Factor);
    
    T_anterior_dibujo = Tiempos(1);
    
    % Inicializamos el trazo de trayectoria con un PlotHandle vacio.
    handles.h_tray_corte = plot3(ax, NaN, NaN, NaN, 'y-', 'LineWidth', 1.5, 'DisplayName', 'Corte (Trabajo)');
    handles.h_tray_traslado = plot3(ax, NaN, NaN, NaN, 'c--', 'LineWidth', 1.5, 'DisplayName', 'Traslado (Rapido)');
    
    % Variables para acumular puntos de cada tipo de trayectoria
    Trayectoria_Corte = []; 
    Trayectoria_Traslado = []; 
    
    % Nueva variable para rastrear el estado anterior del flag
    flag_anterior = TrayArt(1, 4); 
    
    for i = 1:num_puntos
        % Saltar si es un punto de separacion (NaN)
        if any(isnan(TrayArt_plot(i, 1:3))), continue; end
        
        % 2. DIBUJO Y ACTUALIZACION
        if mod(i, skip_rate) == 0 || i == num_puntos
            
            % 1. CALCULO DE LA PAUSA REALISTA
            T_actual = Tiempos(i);
            dt_real = T_actual - T_anterior_dibujo; 
            pause_duration = dt_real / SpeedUp_Factor;
            
            if ~isfinite(pause_duration) || pause_duration < 0
                pause_duration = 1e-9; 
            end
            
            Q_Art = TrayArt_plot(i, 1:3); % [d1, th2, th3]
            flag_corte = TrayArt(i, 4); 
            
            % --- Llamada a CinematicaDirecta ---
            P_cartesiano_fila = CinematicaDirecta(Q_Art, L1, L2); 
            X = P_cartesiano_fila(1); Y = P_cartesiano_fila(2); Z = P_cartesiano_fila(3); 
            
            % Puntos para PLOT3 (Brazos)
            P_base_z0 = [0; 0; 0];
            P_base_z1 = [0; 0; Z]; 
            P_codo = [L1*cos(Q_Art(2)); L1*sin(Q_Art(2)); Z]; 
            P_mano_col = [X; Y; Z]; 
            P_mano_fila = P_cartesiano_fila; 
            
            % 3. Inicializacion de Handles (Colores Fijos)
            if ~isfield(handles, 'h_prism') 
                handles.h_prism = plot3(ax, [P_base_z0(1) P_base_z1(1)], [P_base_z0(2) P_base_z1(2)], [P_base_z0(3) P_base_z1(3)], ...
                    'Color', [0.5 0.5 0.5], 'LineWidth', 6, 'LineStyle', '-', 'DisplayName', 'Articulacion 1 (d1, prismatica)');
                handles.h_brazo1 = plot3(ax, [P_base_z1(1) P_codo(1)], [P_base_z1(2) P_codo(2)], [P_base_z1(3) P_codo(3)], ...
                    '-', 'LineWidth', 4, 'Color', [0 0 1], 'MarkerSize', 8, 'DisplayName', 'Articulacion 2 (th2, rotativa)'); 
                handles.h_brazo2 = plot3(ax, [P_codo(1) P_mano_col(1)], [P_codo(2) P_mano_col(2)], [P_codo(3) P_mano_col(3)], ...
                    '-', 'LineWidth', 4, 'Color', [0 1 0], 'MarkerSize', 8, 'DisplayName', 'Articulacion 3 (th3, rotativa)');
                handles.h_efector_final = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r', 'HandleVisibility', 'off', 'DisplayName', 'Efector final');
                legend(ax, [handles.h_tray_corte, handles.h_tray_traslado, handles.h_prism, handles.h_brazo1, handles.h_brazo2], ...
                    {'Corte (Trabajo)', 'Traslado (Rapido)', 'Articulacion 1 (d1, prismatica)', 'Articulacion 2 (th2, rotativa)', 'Articulacion 3 (th3, rotativa)'}, ...
                    'Location', 'best');
            end
            
            % ***************************************************************
            % *** LOGICA DE SEPARACION Y ASIGNACION DE FLAG CORREGIDA ***
            
            % Reinterpretar como traslado visual si Z supera umbral aunque flag sea 1
            if Q_Art(1) > cut_z_threshold
                flag_visual = 3;
            else
                flag_visual = flag_corte;
            end

            if flag_visual == 1 % MODO CORTE (FLAG=1)
                
                % CLAVE: Si venimos de un traslado (FLAG=2 o 3), rompemos el trazo de CORTE
                if flag_anterior >= 2 && ~isempty(Trayectoria_Corte)
                    Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]];
                end
                
                Trayectoria_Corte = [Trayectoria_Corte; P_mano_fila];
                
                % Ocultamos el trazo de traslado si es el primer punto de corte
                if flag_anterior >= 2 % Solo en el primer punto de corte despues de un salto
                     Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]]; % Rompe el trazo de traslado
                end

                set(handles.h_efector_final, 'XData', X, 'YData', Y, 'ZData', Z);
                
            elseif flag_visual >= 2 % MODO TRASLADO (FLAG=2 o 3)
                
                % CLAVE: Si venimos de un corte (FLAG=1), rompemos el trazo de TRASLADO
                if flag_anterior == 1 && ~isempty(Trayectoria_Traslado)
                     Trayectoria_Traslado = [Trayectoria_Traslado; [NaN NaN NaN]];
                end
                
                Trayectoria_Traslado = [Trayectoria_Traslado; P_mano_fila];

                % Ocultamos el trazo de corte si es el primer punto de traslado
                if flag_anterior == 1
                     Trayectoria_Corte = [Trayectoria_Corte; [NaN NaN NaN]]; % Rompe el trazo de corte
                end
                
                set(handles.h_efector_final, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            end
            
            % ACTUALIZACION DEL FLAG ANTERIOR!
            flag_anterior = flag_visual; 
            % ***************************************************************
            
            % 4. Actualizacion de Posicion de Brazos (Movimiento de la estructura)
            set(handles.h_prism, 'ZData', [P_base_z0(3) P_base_z1(3)]);
            set(handles.h_brazo1, 'XData', [P_base_z1(1) P_codo(1)], 'YData', [P_base_z1(2) P_codo(2)], 'ZData', [P_base_z1(3) P_codo(3)]);
            set(handles.h_brazo2, 'XData', [P_codo(1) P_mano_col(1)], 'YData', [P_codo(2) P_mano_col(2)], 'ZData', [P_codo(3) P_mano_col(3)]);
            
            % 5. Actualizacion del Trazo (Separa los dos colores)
            if ~isempty(Trayectoria_Corte)
                set(handles.h_tray_corte, 'XData', Trayectoria_Corte(:,1), 'YData', Trayectoria_Corte(:,2), 'ZData', Trayectoria_Corte(:,3));
            end
            if ~isempty(Trayectoria_Traslado)
                set(handles.h_tray_traslado, 'XData', Trayectoria_Traslado(:,1), 'YData', Trayectoria_Traslado(:,2), 'ZData', Trayectoria_Traslado(:,3));
            end
            
            drawnow limitrate;
            
            % 6. PAUSA BASADA EN TIEMPO REAL
            pause(pause_duration);
            
            % ACTUALIZACION CRUCIAL! SOLO ACTUALIZAMOS T_ANTERIOR AQUI.
            T_anterior_dibujo = T_actual;
        end
    end
    
    fprintf(' Animacion finalizada. Velocidad visual fiel al perfil de velocidad trapezoidal (x%.0f).\n', SpeedUp_Factor);
end
