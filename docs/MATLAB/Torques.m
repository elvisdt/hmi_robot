function tau = Torques(q, dq, ddq, params)
% TORQUES - Calcula el vector de Torques/Fuerzas articulares (tau) usando Din  mica Inversa.
% Entradas:
%   q, dq, ddq - Posici  n, velocidad y aceleraci  n articulares
%   params     - Estructura de par  metros (incluye B y F_ext)
% Requisitos: Jacobiano.m debe ser accesible.

    % 1. Obtener los componentes del modelo din  mico
    [M, C, G] = ModeloDin(q, dq, params); % <<-- Llama a ModeloDin
    
    % 2. Fricci  n Viscosa (Fv)
    Fv = zeros(3,1);
    if isfield(params,'B')
        Fv = params.B(:) .* dq(:); 
    end
    
    % 3. Fuerzas Externas (tau_ext)
    tau_ext = zeros(3,1);
    if isfield(params,'F_ext') && any(params.F_ext(:)~=0)
        F_ext = params.F_ext(:);
        d1 = q(1); th2 = q(2); th3 = q(3);
        
        % Llama a Jacobiano (funci  n externa)
        Jv_local = Jacobiano(d1, th2, th3, params); 
        
        tau_ext = Jv_local' * F_ext; 
    end
    
    % 4. Din  mica Inversa: tau = M * ddq + C * dq + G + Fv + tau_ext
    tau = M * ddq + C * dq + G + Fv + tau_ext;
    
    if any(isnan(tau))
        tau = [NaN; NaN; NaN];
    end
end