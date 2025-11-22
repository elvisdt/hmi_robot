function grupos_completos = PosicionGuardado(grupos_figura, P_home_cart_mm, Z_home_mm)
% POSICIONGUARDADO - Extiende la trayectoria bruta (celda de grupos) con los
%                    segmentos de traslado de Home al inicio del corte y del 
%                    final del corte al Home.
%
% FLAG KEY: 1=Corte (Z_cut), 0=No Cortar (Z_cut), 2=Reposo (Z_home), 3=Traslado Seguro (Z_home)

    % --- 1. CORRECCIÓN CLAVE DE DIMENSIONES ---
    if size(grupos_figura, 2) > size(grupos_figura, 1) && size(grupos_figura, 1) == 1
        grupos_figura = grupos_figura';
    end
    
    % --- 2. EXTRACCIÓN DE PUNTOS CLAVE DE LA FIGURA ---
    Primer_Grupo_Figura = grupos_figura{1};
    Ultimo_Grupo_Figura = grupos_figura{end};
    
    X_ini_fig = Primer_Grupo_Figura(1, 1);
    Y_ini_fig = Primer_Grupo_Figura(1, 2);
    X_fin_fig = Ultimo_Grupo_Figura(end, 1);
    Y_fin_fig = Ultimo_Grupo_Figura(end, 2);
    
    % Puntos seguros (a la altura Z_home para el traslado)
    P_inicio_fig_safe = [X_ini_fig, Y_ini_fig, Z_home_mm]; % Inicio figura a Z_home
    P_fin_fig_safe    = [X_fin_fig, Y_fin_fig, Z_home_mm]; % Fin figura a Z_home
    
    % --- 3. CREACIÓN DE GRUPOS DE TRASLADO ---
    
    % TRAMO A: HOME (FLAG=2) -> INICIO DE FIGURA (FLAG=3)
    Tramo_A_mat = [
        P_home_cart_mm,         2; % [X Y Z FLAG=2] - REPOSO / GUARDADO (V=0)
        P_inicio_fig_safe,      3  % [X Y Z FLAG=3] - TRASLADO SEGURO (High-Z)
    ];
    Tramo_A = mat2cell(Tramo_A_mat, ones(1, size(Tramo_A_mat, 1)), 4); 
    
    % TRAMO E: FIN DE FIGURA (FLAG=3) -> HOME (FLAG=2)
    Tramo_E_mat = [
        P_fin_fig_safe,         3; % [X Y Z FLAG=3] - TRASLADO SEGURO (High-Z)
        P_home_cart_mm,         2  % [X Y Z FLAG=2] - REGRESO A REPOSO / GUARDADO (V=0)
    ];
    Tramo_E = mat2cell(Tramo_E_mat, ones(1, size(Tramo_E_mat, 1)), 4); 
    
    % --- 4. CONCATENACIÓN FINAL DE LA CELDA ---
    grupos_completos = [
        Tramo_A;        % [Home(2) -> Traslado Seguro(3)]
        grupos_figura;  % [Figura Principal(1 o 0)]
        Tramo_E         % [Traslado Seguro(3) -> Home(2)]
    ];
end