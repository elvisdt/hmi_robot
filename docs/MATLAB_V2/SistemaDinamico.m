function Xdot = SistemaDinamico(t, X, params, Q_d, Q_dot_d, Q_ddot_d, Tiempos_d)
    
    % -------------------------------------------------------------
    % 1. DESEMPAQUETAR ESTADO ACTUAL (FEEDBACK)
    % -------------------------------------------------------------
    q  = X(1:3);   % Posicion actual real
    dq = X(4:6);   % Velocidad actual real
    
    % -------------------------------------------------------------
    % 2. OBTENER REFERENCIAS DESEADAS (INTERPOLACION) <--- ESTE BLOQUE VA AQUI!
    % Las variables q_d_val, dq_d_val, ddq_d_val se DEFINEN aqui
    % -------------------------------------------------------------
    % Usamos 'interp1' para obtener la referencia en el tiempo actual 't'
    q_d_val   = interp1(Tiempos_d, Q_d, t)';
    dq_d_val  = interp1(Tiempos_d, Q_dot_d, t)';
    ddq_d_val = interp1(Tiempos_d, Q_ddot_d, t)';
    
    % -------------------------------------------------------------
    % 3. CEREBRO DEL ROBOT (CONTROLADOR)
    % -------------------------------------------------------------
    % AHORA, las variables q_d_val, dq_d_val, ddq_d_val son reconocidas:
    tau_control = ControlCTC(q, dq, q_d_val, dq_d_val, ddq_d_val, params);
    
    % (Opcional) AQUI iria el DOB para modificar tau_control...
    
    % -------------------------------------------------------------
    % 4. FISICA REAL (PLANTA)
    % -------------------------------------------------------------
    
    % A. Definimos la realidad (Parametros con error e incertidumbre)
    params_real = params;
    params_real.m1 = params.m1 * params.m_error_factor; 
    params_real.m2 = params.m2 * params.m_error_factor;
    params_real.m3 = params.m3 * params.m_error_factor;
    
    % B. Dinamica Real (Matrices M, C, G reales)
    [M_real, C_real, G_real] = ModeloDin(q, dq, params_real);
    
    % C. Friccion Real y Fuerzas Externas Reales (Perturbaciones)
    dist = perturbaciones(t, q, dq); 
    Fv_real = params_real.B .* dq;
    
    %  Fuerzas Externas REALES (CORRECCION: Incluir la fuerza externa real en H_real)
    Jv_local_real = Jacobiano(q(1), q(2), q(3), params_real); 
    tau_ext_real = Jv_local_real' * params_real.F_ext(:);
    
    % -------------------------------------------------------------
    % 5. ECUACION DE MOVIMIENTO (DINAMICA DIRECTA)
    % -------------------------------------------------------------
    
    Tau_Total_Aplicado = tau_control + dist; 
    
    % H_real incluye C*dq + G + Fv + tau_ext_real
    H_real = C_real*dq + G_real + Fv_real + tau_ext_real; 
    
    ddq_real = M_real \ (Tau_Total_Aplicado - H_real);
    
    % -------------------------------------------------------------
    % 6. SALIDA (DERIVADA DEL ESTADO)
    % -------------------------------------------------------------
    Xdot = [dq; ddq_real];
end