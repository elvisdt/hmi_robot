function Xdot = SistemaDinamico(t, X, params, Q_d, Q_dot_d, Q_ddot_d, Tiempos_d)
    
    % 1. DESEMPAQUETAR ESTADO ACTUAL (FEEDBACK)
    q  = X(1:3);   % Posicion actual real
    dq = X(4:6);   % Velocidad actual real
    
    % 2. OBTENER REFERENCIAS DESEADAS (INTERPOLACION) <--- ORDEN CORREGIDO
    q_d_val   = interp1(Tiempos_d, Q_d, t)';
    dq_d_val  = interp1(Tiempos_d, Q_dot_d, t)';
    ddq_d_val = interp1(Tiempos_d, Q_ddot_d, t)';
    
    % 3. CEREBRO DEL ROBOT (CONTROLADOR)
    % Usa las variables de referencia q_d_val, dq_d_val, ddq_d_val definidas arriba.
    tau_control = ControlCTC(q, dq, q_d_val, dq_d_val, ddq_d_val, params);
    
    % -------------------------------------------------------------
    % 4. FISICA REAL (PLANTA)
    % -------------------------------------------------------------
    
    % Definimos la realidad (Parametros con error)
    params_real = params;
    params_real.m1 = params.m1 * params.m_error_factor; 
    params_real.m2 = params.m2 * params.m_error_factor;
    params_real.m3 = params.m3 * params.m_error_factor;
    
    % Dinamica Real
    [M_real, C_real, G_real] = ModeloDin(q, dq, params_real);
    
    % Friccion Real y Perturbaciones
    dist = perturbaciones(t, q, dq); 
    Fv_real = params_real.B .* dq;
    
    %  Fuerzas Externas REALES (Compensacion de la planta)
    Jv_local_real = Jacobiano(q(1), q(2), q(3), params_real); 
    tau_ext_real = Jv_local_real' * params_real.F_ext(:);
    
    % -------------------------------------------------------------
    % 5. ECUACION DE MOVIMIENTO (DINAMICA DIRECTA)
    % -------------------------------------------------------------
    
    Tau_Total_Aplicado = tau_control + dist; 
    
    % H_real incluye todos los terminos no inerciales de la planta real
    H_real = C_real*dq + G_real + Fv_real + tau_ext_real; 
    
    ddq_real = M_real \ (Tau_Total_Aplicado - H_real);
    
    % -------------------------------------------------------------
    % 6. SALIDA (DERIVADA DEL ESTADO)
    % -------------------------------------------------------------
    Xdot = [dq; ddq_real];
end