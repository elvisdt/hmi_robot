function [M, C, G] = ModeloDin(q, dq, params)
% MODELODIN - Calcula las matrices M, C y el vector G para el SCARA P-R-R.
% Entradas:
%   q, dq    - Posición y velocidad articulares [d1; th2; th3]
%   params   - Estructura con parámetros dinámicos (L1, L2, m1, m2, m3, I2, I3, g)

    % 0. Extracción de Parámetros y Variables
    d1 = q(1); th2 = q(2); th3 = q(3);
    d1_dot = dq(1); dth2 = dq(2); dth3 = dq(3);
    L1 = params.L1; L2 = params.L2;
    g  = params.g;
    m1 = params.m1; m2 = params.m2; m3 = params.m3;
    I2 = params.I2; I3 = params.I3;
    
    % Parámetros de Centro de Masa
    Cm_L1 = 0.3 * L1; 
    Cm_L2 = 0.3 * L2;
    m_total = m1 + m2 + m3;
    c3 = cos(th3);
    s3 = sin(th3);

    % --- M: Matriz de Masa (3x3) ---
    M = zeros(3,3);
    M(1,1) = m_total; 
    M(2,2) = I2 + I3 + m2*(Cm_L1)^2 + m3*(L1^2 + (Cm_L2)^2 + 2*L1*(Cm_L2)*c3);
    M(2,3) = I3 + m3*((Cm_L2)^2 + L1*(Cm_L2)*c3);
    M(3,2) = M(2,3);
    M(3,3) = I3 + m3*(Cm_L2)^2;

    % --- C: Matriz de Coriolis y Centrífuga (3x3) ---
    C = zeros(3,3);
    h = -m3*L1*Cm_L2*s3;
    C(2,2) = h * dth3;
    C(2,3) = h * (dth2 + dth3);
    C(3,2) = -h * dth2;

    % --- G: Vector de Gravedad (3x1) ---
    G = zeros(3,1);
    G(1) = m_total * g; 
    G(2) = 0; % Asumiendo plano XY horizontal
    G(3) = 0; % Asumiendo plano XY horizontal
end