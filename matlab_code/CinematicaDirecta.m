function P_Cart = CinematicaDirecta(Q_Art, L1, L2)
% CINEMATICADIRECTA - Calcula la posición cartesiana (X, Y, Z) a partir de posiciones articulares (d1, th2, th3) para un SCARA P-R-R.
% Entradas:
%   Q_Art - Vector de posiciones articulares [d1, th2, th3]
%   L1, L2 - Longitudes de los brazos (en metros)
% Salida:
%   P_Cart - Vector de posición cartesiana [X, Y, Z] (en metros)

    % Extracción de variables articulares
    d1  = Q_Art(1); % Desplazamiento Prismático (Z)
    th2 = Q_Art(2); % Ángulo del hombro
    th3 = Q_Art(3); % Ángulo del codo (relativo al hombro)
    
    % Posición del centro del codo (p_codo)
    X_codo = L1 * cos(th2);
    Y_codo = L1 * sin(th2);
    
    % Posición del efector final (P_Cart)
    X = X_codo + L2 * cos(th2 + th3);
    Y = Y_codo + L2 * sin(th2 + th3);
    Z = d1;
    
    P_Cart = [X, Y, Z];
end