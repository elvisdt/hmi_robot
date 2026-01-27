function tau_nom = ControlCTC(q, dq, q_d, dq_d, ddq_d, params)
% CONTROLCTC - Calcula el torque nominal requerido usando la ley de control por torque calculado.
% ENTRADAS:
%   q, dq     - Estado actual (retroalimentado)
%   q_d, ...  - Estado deseado (referencia)
%   params    - Parametros (Kp, Kv, M, C, G nominales)
    
    % 1. Calculo del error
    e    = q_d - q;
    edot = dq_d - dq;
    
    % 2. PD Control Law in Joint Space (Comanded Acceleration 'v')
    % v = ddq_d + Kv * edot + Kp * e 
    v = ddq_d + params.Kv * edot + params.Kp * e;
    
    % 3. Nominal Inverse Dynamics (Calcula M, C, G con el modelo teorico)
    [M, C, G] = ModeloDin(q, dq, params); 
    
    % 4. Compensacion de Friccion Viscosa y Fuerzas Externas Nominales
    Fv = params.B(:) .* dq(:); 
    F_ext_nom = params.F_ext(:);
    
    Jv_local = Jacobiano(q(1), q(2), q(3), params);
    tau_ext_nom = Jv_local' * F_ext_nom;
    
    % 5. Control Torque: tau = M * v + H_nominal
    % H_nominal = C * dq + G + Fv + tau_ext
    tau_nom = M * v + C * dq + G + Fv + tau_ext_nom;
end