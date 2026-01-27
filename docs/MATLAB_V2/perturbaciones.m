function dist = perturbaciones(t, q, dq)
% PERTURBACIONES - Modelo de perturbaciones externas realistas
    
    dist = zeros(3,1);
    
    %% ============================
    %  1) Friccion viscosa
    % ============================
    % Valores reducidos para evitar sobreamortiguamiento y ruido de control
    Kv = [0.3; 0.05; 0.03]; 
    dist = dist - Kv .* dq;
    
    %% ============================
    %  2) Friccion Coulomb
    % ============================
    % Se incluye deadband para evitar oscilaciones en reposo
    Fc = [0.2; 0.08; 0.04];
    deadband = 1e-3;
    dist = dist - Fc .* sign(dq) .* (abs(dq) > deadband);
    
    %% ============================
    %  3) Ruido tipo "encoder"
    % ============================
    % Amplitud reducida y acotada para evitar picos
    noise_amp = [0.002; 0.001; 0.0005];
    noise = noise_amp .* randn(3,1);
    noise = max(min(noise, 3*noise_amp), -3*noise_amp);
    dist = dist + noise;
    
    %% ============================
    %  4) Torque externo tipo impacto
    % ============================
    % Pulso breve y reducido para pruebas de robustez del DOB
    if t > 4 && t < 4.05
        dist(2) = dist(2) + 2;  % impacto corto en articulacion 2
    end

    %% ============================
    %  5) Saturacion global de perturbacion
    % ============================
    dist = max(min(dist, 5), -5);
end
