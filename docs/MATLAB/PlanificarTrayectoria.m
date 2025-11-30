function TrayFinal = PlanificarTrayectoria(TrayInt, Z_home, Z_cut, paso, Speed_cut, Speed_traslado, A_max_cart)
% PLANIFICARTRAYECTORIA - Genera trayectoria 3D, incluyendo perfiles de velocidad suavizados (Trapezoidal).
% Regenera el movimiento de salto completo (Lift-XY-Plunge) entre bloques.
%
% FLAG KEY: 1=Corte, 2=Reposo, 3=Traslado Seguro.
    
    % --- 1. Definici  n y Conversi  n de Entradas ---
    if nargin < 4, paso = 1; end         
    if nargin < 5, Speed_cut = 5000; end    
    if nargin < 6, Speed_traslado = 15000; end 
    if nargin < 7, A_max_cart = 2000; end 
    
    V_cut_ms = (Speed_cut / 1000) / 60;        % m/s
    V_traslado_ms = (Speed_traslado / 1000) / 60; % m/s
    A_max_ms2 = A_max_cart / 1000;              % m/s^2
    dL_cart = paso / 1000;                      % distancia entre puntos (m)
    
    TrayFinal = [];
    
    % --- 2. CONSTRUCCI  N DE LA TRAYECTORIA INICIAL [X Y Z FLAG V_DESEADA] ---
    idx_nan = find(isnan(TrayInt(:,1)));
    idx_nan = [0; idx_nan; size(TrayInt,1)+1];
    
    for b = 1:length(idx_nan)-1
        ini = idx_nan(b)+1;
        fin = idx_nan(b+1)-1;
        if fin < ini, continue; end
        
        bloque = TrayInt(ini:fin, :);
        nb = size(bloque,1);
        flag_bloque = bloque(1,4); 
        
        % 2.2. Manejo de Transiciones y Enlaces (L  gica de Salto Completo)
        
        if isempty(TrayFinal)
            % 1) INICIO ABSOLUTO (Home(2) -> Traslado Seguro(3) -> Bajada)
            
            V_deseada = V_traslado_ms * ones(nb,1);
            V_deseada(bloque(:,4) == 2) = 0; % FLAG=2 (Reposo) -> V=0
            
            p_end_safe = bloque(end, 1:3); %   ltimo punto del traslado seguro (a Z_home)
            
            % ** INSERTAR LA BAJADA VERTICAL (PLUNGE) **
            Z_cut_target = Z_cut; 

            nZ = max(2, ceil(abs(Z_cut_target - p_end_safe(3))/paso)); 
            Z_down = linspace(p_end_safe(3), Z_cut_target, nZ)'; 
            
            trans_ini_plunge = [ ...
                p_end_safe(1)*ones(nZ,1), ...
                p_end_safe(2)*ones(nZ,1), ...
                Z_down, ...                                    
                3*ones(nZ,1), ...                              
                V_traslado_ms*ones(nZ,1)];                     
            
            % Forzar V=0 y FLAG=1 al final de la bajada (inicio de corte)
            trans_ini_plunge(end, 5) = 0; 
            trans_ini_plunge(end, 4) = 1; 
            
            bloque_vel = [bloque(:,1:4), V_deseada];
            TrayFinal = [TrayFinal; bloque_vel; trans_ini_plunge(2:end,:)]; 
            
        else
            % 2) TRANSICI  N ENTRE BLOQUES (El NaN gap) - SALTO COMPLETO
            p_prev = TrayFinal(end,1:3);    
            p_ini  = bloque(1,1:3);         
            Z_cut_prev = p_prev(3);
            Z_cut_next = p_ini(3); 
            
            % --- CORRECCI  N CLAVE: Punto de Transici  n ---
            % Se inserta un punto id  ntico al final del corte, pero marcado como FLAG=3.
            % Esto rompe la continuidad visual del color amarillo en Z_cut.
            P_transicion = [p_prev(1), p_prev(2), Z_cut_prev, 3, V_traslado_ms];
            
            % A) subida a Z_home (LIFT)
            n1 = max(2, ceil(abs(Z_home - Z_cut_prev)/paso));
            trans_up = [];
            if abs(Z_home - Z_cut_prev) > 1e-6 % Solo si no est   ya en Z_home
                Z_up = linspace(Z_cut_prev, Z_home, n1)';
                trans_up = [p_prev(1)*ones(n1-1,1), p_prev(2)*ones(n1-1,1), Z_up(2:end), 3*ones(n1-1,1), V_traslado_ms*ones(n1-1,1)];
            end
            
            % B) Movimiento XY a Z_home (TRASLADO HORIZONTAL)
            dist_xy = norm(p_ini(1:2)-p_prev(1:2));
            n2 = max(2, ceil(dist_xy/paso));
            X_lin = linspace(p_prev(1), p_ini(1), n2+1)';
            Y_lin = linspace(p_prev(2), p_ini(2), n2+1)';
            trans_xy = [X_lin(2:end), Y_lin(2:end), Z_home*ones(n2,1), 3*ones(n2,1), V_traslado_ms*ones(n2,1)]; 
            
            % C) bajada a Z_cut (PLUNGE)
            n3 = max(2, ceil(abs(Z_cut_next - Z_home)/paso));
            trans_down = [];
            if abs(Z_home - Z_cut_next) > 1e-6 % Solo si el destino no es Z_home
                Z_down = linspace(Z_home, Z_cut_next, n3)';
                trans_down = [p_ini(1)*ones(n3-1,1), p_ini(2)*ones(n3-1,1), Z_down(2:end), 3*ones(n3-1,1), V_traslado_ms*ones(n3-1,1)];
                
                %   ltimo punto de bajada = inicio de corte (FLAG=1, V=0)
                trans_down(end,4) = 1; 
                trans_down(end,5) = 0; 
            end
            
            % Concatenar: Punto de transici  n (rompe color), LIFT, XY, PLUNGE
            TrayFinal = [TrayFinal; P_transicion; trans_up; trans_xy; trans_down];
        end
        
        % 3) Bloque de trabajo principal (FLAG=1) o Reposo (FLAG=2/3)
        if flag_bloque == 1 
            V_deseada = V_cut_ms * ones(nb,1);
            V_deseada(end) = 0; % Forzar detenci  n al final del corte
        elseif flag_bloque == 2 
            V_deseada = zeros(nb,1); 
        elseif flag_bloque == 3 
            V_deseada = V_traslado_ms * ones(nb,1);
        else
            V_deseada = V_traslado_ms * ones(nb,1); 
        end
        
        bloque_vel = [bloque(:,1:4), V_deseada]; 
        TrayFinal = [TrayFinal; bloque_vel];

    end % Fin del loop for b
    
    % 4) Subida final a Z_home y punto de Reposo (FLAG=2)
    if ~isempty(TrayFinal)
        p_fin = TrayFinal(end,1:3); 
        
        if abs(p_fin(3)-Z_home) > 1e-9 && TrayFinal(end, 4) ~= 2
            n_end = max(2, ceil(abs(Z_home - p_fin(3))/paso));
            Z_end_tray = linspace(p_fin(3), Z_home, n_end)';
            final_up = [p_fin(1)*ones(n_end-1,1), p_fin(2)*ones(n_end-1,1), Z_end_tray(2:end), 3*ones(n_end-1,1), V_traslado_ms*ones(n_end-1,1)];
            TrayFinal = [TrayFinal; final_up];
        end
        
        % Asegurar que el   ltimo punto sea de Reposo (FLAG=2, V=0)
        if TrayFinal(end, 4) ~= 2
             % Usamos el   ltimo XY alcanzado y Z_home
             TrayFinal = [TrayFinal; p_fin(1), p_fin(2), Z_home, 2, 0]; 
        end
    end

% --------------------------------------------------------------------------------
%       Aplicaci  n del Perfil de Velocidad Trapezoidal (Secci  n 3)
% --------------------------------------------------------------------------------

    V_deseada = TrayFinal(:, 5);
    Flags = TrayFinal(:, 4); 
    N = size(TrayFinal, 1);
    V_perfilada = zeros(N, 1);
    dL = dL_cart;
    
    % 3.1. Iteraci  n hacia adelante (Aceleraci  n)
    V_perfilada(1) = 0; 
    for i = 2:N
        V_prev = V_perfilada(i-1);          
        V_target = V_deseada(i);            
        
        % Forzar V=0 en puntos de reposo o inicio/fin de corte/transici  n
        if Flags(i) == 2 || Flags(i-1) == 2 || (Flags(i) == 1 && Flags(i-1) ~= 1) || (Flags(i) == 3 && Flags(i-1) == 1)
            V_target = 0; 
            V_prev = 0;   
        end
        
        V_max_acel_sq = V_prev^2 + 2 * A_max_ms2 * dL;
        V_max_acel = sqrt(max(0, V_max_acel_sq));
        
        V_perfilada(i) = min(V_target, V_max_acel);
    end
    
    % 3.2. Iteraci  n hacia atr  s (Desaceleraci  n)
    V_perfilada(N) = 0; 
    for i = N-1:-1:1
        V_next = V_perfilada(i+1);
        
        if Flags(i) == 2 || Flags(i+1) == 2 || (Flags(i) == 1 && Flags(i+1) ~= 1) || (Flags(i) == 1 && Flags(i+1) == 3)
             V_perfilada(i) = 0; 
             continue; 
        end
        
        V_limit_decel_sq = V_next^2 + 2 * A_max_ms2 * dL_cart;
        V_limit_decel = sqrt(max(0, V_limit_decel_sq));
        
        V_perfilada(i) = min(V_perfilada(i), V_limit_decel);
    end
    
    % Asignar la velocidad perfilada final (columna 5)
    TrayFinal(:, 5) = V_perfilada;
    
% --------------------------------------------------------------------------------
%       Conversi  n y Limpieza Final (Secci  n 4)
% --------------------------------------------------------------------------------

    % Conversi  n de [mm] a [m] para las coordenadas
    TrayFinal(:,1:3) = TrayFinal(:,1:3)/1000;         
    
    % Manejo de valores no finitos (para estabilidad)
    vmin = 1e-6;
    TrayFinal(~isfinite(TrayFinal(:,5)),5) = vmin;
    TrayFinal(TrayFinal(:,5) < vmin,5) = vmin;
    
    fprintf('    Trayectoria final planificada y perfilada (m y m/s). V_cut=%g m/s, V_traslado=%g m/s. A_max=%g m/s^2\n', V_cut_ms, V_traslado_ms, A_max_ms2);
end