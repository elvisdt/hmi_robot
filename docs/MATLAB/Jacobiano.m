function J = Jacobiano(d1, th2, th3, params)
% JACOBIANO - Calcula la matriz Jacobiana (3x3) para un robot SCARA P-R-R.
    L1 = params.L1; L2 = params.L2;
    % Shorthand trigonom  trico
    C2 = cos(th2);
    S2 = sin(th2);
    C23 = cos(th2 + th3);
    S23 = sin(th2 + th3);
    
    J = zeros(3, 3);
    
    % Columna 1: Articulaci  n Prism  tica (d1)
    J(1, 1) = 0; 
    J(2, 1) = 0; 
    J(3, 1) = 1; 
    
    % Columna 2: Articulaci  n Revoluta (theta2)
    J(1, 2) = -L1 * S2 - L2 * S23;
    J(2, 2) = L1 * C2 + L2 * C23; 
    J(3, 2) = 0;                  
    
    % Columna 3: Articulaci  n Revoluta (theta3)
    J(1, 3) = -L2 * S23; 
    J(2, 3) = L2 * C23;  
    J(3, 3) = 0;         
end