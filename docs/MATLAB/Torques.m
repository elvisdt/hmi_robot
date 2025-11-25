function tau = Torques(q, dq, ddq, params)
% TORQUES - Calcula el vector de Torques/Fuerzas articulares (tau) usando Dinámica Inversa.
% Entradas:
%   q, dq, ddq - Posición, velocidad y aceleración articulares
%   params     - Estructura de parámetros (incluye B y F_ext)
% Requisitos: Jacobiano.m debe ser accesible.

    % 1. Obtener los componentes del modelo dinámico
    [M, C, G] = ModeloDin(q, dq, params); % <<-- Llama a ModeloDin
    
    % 2. Fricción Viscosa (Fv)
    Fv = zeros(3,1);
    if isfield(params,'B')
        Fv = params.B(:) .* dq(:); 
    end
    
    % 3. Fuerzas Externas (tau_ext)
    tau_ext = zeros(3,1);
    if isfield(params,'F_ext') && any(params.F_ext(:)~=0)
        F_ext = params.F_ext(:);
        d1 = q(1); th2 = q(2); th3 = q(3);
        
        % Llama a Jacobiano (función externa)
        Jv_local = Jacobiano(d1, th2, th3, params); 
        
        tau_ext = Jv_local' * F_ext; 
    end
    
    % 4. Dinámica Inversa: tau = M * ddq + C * dq + G + Fv + tau_ext
    tau = M * ddq + C * dq + G + Fv + tau_ext;
    
    if any(isnan(tau))
        tau = [NaN; NaN; NaN];
    end
end