function Xdot = SistemaDinamico_DOB(t, X, params, Q_d, Q_dot_d, Q_ddot_d, Tiempos_d)
    
    % -------------------------------------------------------------
    % 1. DESEMPAQUETAR ESTADO ACTUAL (FEEDBACK REAL Y ESTIMACION DOB)
    % -------------------------------------------------------------
    q       = X(1:3);   % Posicion actual real
    dq      = X(4:6);   % Velocidad actual real
    d_hat   = X(7:9);   % Estimacion de Perturbacion del DOB
    
    % -------------------------------------------------------------
    % 2. OBTENER REFERENCIAS DESEADAS
    % -------------------------------------------------------------
    q_d_val   = interp1(Tiempos_d, Q_d, t)';
    dq_d_val  = interp1(Tiempos_d, Q_dot_d, t)';
    ddq_d_val = interp1(Tiempos_d, Q_ddot_d, t)';
    
    % -------------------------------------------------------------
    % 3. CEREBRO DEL ROBOT (CONTROLADOR CTC + DOB)
    % -------------------------------------------------------------
    % A. Torque Nominal de CTC: tau_nom = M*v + H_nom
    tau_nom = ControlCTC(q, dq, q_d_val, dq_d_val, ddq_d_val, params);
    
    % B. Dinamica Nominal para el DOB (Prediccion de Perturbacion)
    [M_nom, C_nom, G_nom] = ModeloDin(q, dq, params);
    
    % C. Friccion y Fuerzas Externas Nominales
    Fv_nom = params.B(:) .* dq(:); 
    Jv_nom = Jacobiano(q(1), q(2), q(3), params);
    tau_ext_nom = Jv_nom' * params.F_ext(:);
    
    % D. Torque Predicho por el Modelo Nominal (para alcanzar ddq_d)
    % Se asume que q=q_d y dq=dq_d para la Dinamica Inversa Nominal,
    % pero el observador debe usar el estado real (q, dq) para ver la diferencia.
    tau_model_pred = M_nom * ddq_d_val + C_nom * dq + G_nom + Fv_nom + tau_ext_nom;
    
    % E. Estimacion Instantanea de la Perturbacion (antes del filtro)
    % Diferencia entre el torque aplicado nominalmente y lo que predice el modelo nominal
    tau_dist_est = tau_nom - tau_model_pred; 
    
    % F. Derivada del Estado del DOB (Filtro de Primer Orden)
    % La derivada del estado del observador: d(d_hat)/dt = w0 * (tau_dist_est - d_hat)
    % w0 es la frecuencia de corte
    w0 = params.DOB_w0;
    d_hat_dot = w0 * (tau_dist_est - d_hat); 
    
    % G. Torque Total Aplicado a la Planta (CTC + Compensacion DOB)
    tau_control_final = tau_nom + d_hat; 
    
    % -------------------------------------------------------------
    % 4. FISICA REAL (PLANTA)
    % -------------------------------------------------------------
    
    % A. Parametros Reales (con error de masa)
    params_real = params;
    params_real.m1 = params.m1 * params.m_error_factor; 
    params_real.m2 = params.m2 * params.m_error_factor;
    params_real.m3 = params.m3 * params.m_error_factor;
    
    % B. Dinamica Real
    [M_real, C_real, G_real] = ModeloDin(q, dq, params_real);
    
    % C. Friccion y Fuerzas Externas Reales
    dist_no_modelado = perturbaciones(t, q, dq); % Friccion Coulomb, Ruido, Impactos
    Fv_real = params_real.B .* dq;
    Jv_local_real = Jacobiano(q(1), q(2), q(3), params_real); 
    tau_ext_real = Jv_local_real' * params_real.F_ext(:); % Fuerzas externas de la herramienta
    
    % D. Torque Neto que mueve al robot
    % Torque_Control - Dinamica_No_Modelada - Perturbaciones_Externas
    Tau_Neto = tau_control_final - dist_no_modelado;
    
    % E. H_real incluye C*dq + G + Fv + tau_ext_real
    H_real = C_real*dq + G_real + Fv_real + tau_ext_real; 
    
    % 5. ECUACION DE MOVIMIENTO (DINAMICA DIRECTA)
    % M * ddq = Tau_Neto - H_real
    ddq_real = M_real \ (Tau_Neto - H_real);
    
    % 6. SALIDA (DERIVADA DEL ESTADO)
    % La derivada del estado extendido (9x1)
    Xdot = [dq; ddq_real; d_hat_dot];
end