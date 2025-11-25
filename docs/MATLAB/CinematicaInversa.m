function TrayArt = CinematicaInversa(TrayCart_pos, L1, L2, TrayCart_aux)
% CINEMATICAINVERSA - Convierte trayectorias cartesianas a ángulos y desplazamientos articulares (P-R-R)
% Entradas:
%   TrayCart_pos - Nx3 [X Y Z] (metros)
%   L1, L2       - longitudes de los brazos [m]
%   TrayCart_aux - Nx2 [flag velocidad] (m/s) <--- NUEVO ARGUMENTO DE ENTRADA
% Salida:
%   TrayArt - Nx5 [d1 theta2 theta3 flag velocidad]
    
    n = size(TrayCart_pos,1);
    % La salida se inicializa con 5 columnas: [d1, th2, th3, flag, v]
    TrayArt = zeros(n,5);
    
    for i=1:n
        X = TrayCart_pos(i,1);
        Y = TrayCart_pos(i,2);
        Z = TrayCart_pos(i,3);
        
        % --- CÁLCULO DE CINEMÁTICA INVERSA (NO CAMBIA) ---
        
        % 1. Articulación Prismática (d1):
        d1 = Z;
        
        % 2. Cálculo de ángulos Rotacionales (theta2 y theta3) en el plano XY:
        r_sq = X^2 + Y^2;
        r = sqrt(r_sq);
        
        % Ley de Cosenos
        cos_th3 = (r_sq - L1^2 - L2^2) / (2*L1*L2);
        
        % Límite de alcance
        cos_th3 = min(max(cos_th3,-1),1);  
        
        % Solución "Codo Abajo" (Elbow-down)
        th3 = atan2(sqrt(1 - cos_th3^2), cos_th3); 
        
        % 3. Cálculo de theta2 (Ángulo del Hombro)
        th2_offset = atan2(L2*sin(th3), L1 + L2*cos(th3));
        th2 = atan2(Y,X) - th2_offset;
        
        % --- Asignación de la salida P-R-R ---
        % Formato de salida: [d1, theta2, theta3, flag, v]
        
        % Tomamos el FLAG y la VELOCIDAD del cuarto argumento de entrada
        f = TrayCart_aux(i,1);
        v = TrayCart_aux(i,2); 
        
        TrayArt(i,:) = [d1, th2, th3, f, v];
    end
end