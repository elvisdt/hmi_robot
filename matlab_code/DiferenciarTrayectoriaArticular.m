function [Q_dot, Q_ddot, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params)
% DIFERENCIARTRAYECTORIAARTICULAR - Calcula Q_dot y Q_ddot usando diferencias finitas.
    
    % --- 0. Extracción y Preparación ---
    Q = TrayArt(:, 1:3); % Posiciones Articulares (d1, th2, th3)
    V_ms = TrayArt(:, 5); % Velocidad Cartesiana planificada (m/s)
    num_puntos = size(Q, 1);
    
    Q_dot = zeros(num_puntos, 3);
    Q_ddot = zeros(num_puntos, 3);
    Tiempos = zeros(num_puntos, 1);
    
    if isfield(params, 'paso')
        dL_cart = params.paso / 1000; % paso en metros
    else
        dL_cart = 0.001;
        warning('Parámetro "paso" no encontrado en params. Asumiendo 1 mm (0.001 m).');
    end
    
    if isfield(params, 'Fs')
        dt_min = 1 / params.Fs; % Usamos el periodo de muestreo si está disponible
    else
        dt_min = 0.005; % 5 ms, una asunción razonable
    end
    
    % --- 1. Cálculo de Tiempos (dt) ---
    dL_min = dL_cart * 0.01; % Umbral de distancia mínima (para puntos repetidos)
    
    for i = 2:num_puntos
        dt = dt_min; % Inicializamos con el tiempo mínimo por defecto
        
        % 1. Manejo de distancias/velocidades insignificantes
        if dL_cart < dL_min && V_ms(i) < 1e-6
             % Si la distancia y la velocidad son casi cero, forzamos dt_min
             dt = dt_min;
        
        % 2. Manejo de puntos de detención forzada (V=0)
        elseif V_ms(i) < 1e-6 
            % Si V_perfilada es cero (inicio/fin de corte), forzamos dt_min
            dt = dt_min; 
            
        % 3. Cálculo normal de tiempo
        else
            V_prom_segmento = (V_ms(i) + V_ms(i-1)) / 2;
            
            if V_prom_segmento > 1e-6 
                 dt = dL_cart / V_prom_segmento;
            else
                 % Si V_prom es cero, volvemos al caso seguro de dt_min
                 dt = dt_min; 
            end
        end
        
        Tiempos(i) = Tiempos(i-1) + max(dt, 1e-9); % Acumulación del tiempo
    end
    
    % --- 2. Diferenciación Numérica (Q_dot y Q_ddot) ---
    
    for j = 1:3 % Para cada articulación (d1, th2, th3)
        % Diferencia Forward (Punto inicial)
        dt_ini = Tiempos(2) - Tiempos(1);
        Q_dot(1, j) = (Q(2, j) - Q(1, j)) / dt_ini;
        
        % Diferencia Central y Backward (Puntos intermedios y final)
        for i = 2:num_puntos-1
            dt_span = Tiempos(i+1) - Tiempos(i-1);
            Q_dot(i, j) = (Q(i+1, j) - Q(i-1, j)) / dt_span;
        end
        
        dt_fin = Tiempos(num_puntos) - Tiempos(num_puntos-1);
        Q_dot(num_puntos, j) = (Q(num_puntos, j) - Q(num_puntos-1, j)) / dt_fin;
        
        % Cálculo de Q_ddot a partir de Q_dot (mismo método)
        Q_ddot(1, j) = (Q_dot(2, j) - Q_dot(1, j)) / dt_ini;
        
        for i = 2:num_puntos-1
            dt_span = Tiempos(i+1) - Tiempos(i-1);
            Q_ddot(i, j) = (Q_dot(i+1, j) - Q_dot(i-1, j)) / dt_span;
        end
        
        Q_ddot(num_puntos, j) = (Q_dot(num_puntos, j) - Q_dot(num_puntos-1, j)) / dt_fin;
    end
    
    % --- 2.5. APLICACIÓN DE LÍMITES FÍSICOS ARTICULARES (CORRECCIÓN CRÍTICA) ---
    % Esto asegura que las velocidades y aceleraciones calculadas no superen
    % las capacidades físicas del motor (que es donde reside el cuello de botella real).
    
    if isfield(params, 'Qdot_max')
        % Limitar Velocidad (Q_dot)
        for j = 1:3 
            % Aplica clipping: Q_dot se limita a [-Qdot_max, Qdot_max]
            Q_dot(:, j) = max(-params.Qdot_max(j), min(params.Qdot_max(j), Q_dot(:, j)));
        end
    end
    
    if isfield(params, 'Qddot_max')
        % Limitar Aceleración (Q_ddot)
        for j = 1:3 
            % Aplica clipping: Q_ddot se limita a [-Qddot_max, Qddot_max]
            Q_ddot(:, j) = max(-params.Qddot_max(j), min(params.Qddot_max(j), Q_ddot(:, j)));
        end
    end

    % --- 3. Suavizado de la Aceleración Articular (Q_ddot) ---
    % Se aplica el suavizado DESPUÉS de limitar, para eliminar el ruido residual.
    
    % Ventana de suavizado: 5% del total de puntos (ajustable)
    window_size = max(3, 2 * floor(num_puntos * 0.05 / 2) + 1); 
    
    for j = 1:3 
        % Aplicar filtro de media móvil a Q_ddot
        Q_ddot(:, j) = smoothdata(Q_ddot(:, j), 'movmean', window_size);
    end
    
    % --- 4. Limpieza Final de Ruido Numérico ---
    Q_dot(~isfinite(Q_dot)) = 0;
    Q_ddot(~isfinite(Q_ddot)) = 0;
    Q_dot(abs(Q_dot) < 1e-9) = 0; 
    Q_ddot(abs(Q_ddot) < 1e-6) = 0; 
    
end