function [tau_total, d_hat] = DOB_Update(q, dq, ddq_d, tau_real, params, d_hat_prev)
% DOB_UPDATE - Estima perturbaciones y corrige el torque nominal.
%
% ENTRADAS:
%   q, dq, ddq_d  - estado y referencia aceleracion
%   tau_real      - torque aplicado al sistema (tau_nom + perturbaciones reales)
%   params        - estructura con parametros nominales (incluye Fs y DOB_w0)
%   d_hat_prev    - estimacion previa de perturbacion
%
% SALIDAS:
%   tau_total - tau_real - d_hat (Compensated torque)
%   d_hat     - nueva estimacion de perturbacion
    % Filter Parameters
    w0 = params.DOB_w0;   % Cutoff frequency (rad/s)
    Ts = params.Ts;
    alpha = exp(-w0 * Ts); % Exponential filter factor
    
    % Nominal Torque Prediction
    [M, C, G] = ModeloDin(q, dq, params);
    
    % Nominal Friction and External Forces
    Fv = params.B(:) .* dq(:); 
    F_ext_nom = params.F_ext(:);
    Jv_local = Jacobiano(q(1), q(2), q(3), params);
    tau_ext_nom = Jv_local' * F_ext_nom;

    % Predicted Model Torque: tau_model_pred = M * ddq_d + C * dq + G + Fv + tau_ext_nom
    tau_model_pred = M * ddq_d + C * dq + G + Fv + tau_ext_nom;
    
    % Instantaneous Disturbance Estimation: Difference between applied torque and predicted model torque
    % tau_real = tau_nom + dist (The signal the DOB sees before compensation)
    tau_dist_est = tau_real - tau_model_pred;
    
    % Exponential Filtering (DOB)
    d_hat = alpha * d_hat_prev + (1 - alpha) * tau_dist_est;
    
    % Total Applied Torque (Compensates the disturbance estimation)
    % This is the torque that goes to the real dynamics (M_real * ddq)
    tau_total = tau_real - d_hat;
end