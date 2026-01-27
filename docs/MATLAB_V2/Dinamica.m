function TrayFinalDinamica = Dinamica(TrayArt, params)
% DINAMICA - Pipeline dinamico completo: CTC + DOB + perturbaciones.
%
% ENTRADAS:
%   TrayArt  - Nx5 [d1 th2 th3 flag V]
%   params   - estructura con parametros nominales del robot
%
% SALIDA:
%   TrayFinalDinamica - Nx12:
%     [ q | dq | ddq | tau_total ]
% Autor: Abril (para Harold)
% 2025

    if isempty(TrayArt)
        TrayFinalDinamica = [];
        return;
    end

    num_puntos = size(TrayArt, 1);

    % =============================
    % 1) Perfiles articulares
    % =============================
    [Q_dot, Q_ddot, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params);

    Tau_nom     = zeros(num_puntos, 3);
    Tau_total   = zeros(num_puntos, 3);
    d_hat_hist  = zeros(num_puntos, 3);

    % =============================
    % 2) Inicializacion DOB
    % =============================
    d_hat_prev = zeros(3,1);

    fprintf('   2. Ejecutando bucle CTC + DOB + perturbaciones...\n');

    for i = 1:num_puntos

        % -------------------------
        % Referencias deseadas
        % -------------------------
        q_d   = TrayArt(i, 1:3)';     % d1, th2, th3
        dq_d  = Q_dot(i, :)';
        ddq_d = Q_ddot(i, :)';

        % En este esquema simplificado (sin integracion):
        q  = q_d;
        dq = dq_d;

        % =============================
        % 3) Torque nominal CTC
        % =============================
        tau_nom = ControlCTC(q, dq, q_d, dq_d, ddq_d, params);
        Tau_nom(i, :) = tau_nom(:)';

        % =============================
        % 4) PERTURBACIONES EXTERNAS
        % =============================
        t = Tiempos(i);
        dist = perturbaciones(t, q, dq);

        % =============================
        % 5) ERROR PARAMETRICO (modelo real)
        % =============================
        % El DOB debe ver un mundo real diferente del modelo nominal
        params_real = params;
        params_real.m1 = 1.10 * params.m1;
        params_real.m2 = 1.10 * params.m2;
        params_real.m3 = 1.10 * params.m3;
        % (Puedes aplicar error tambien en inertias o friccion si quieres)

        % =============================
        % 6) DOB (modelo real vs modelo nominal)
        % =============================
        [tau_total, d_hat] = DOB_Update(q, dq, ddq_d, ...
                                        tau_nom + dist, ... % mundo real = nominal + perturbaciones
                                        params, ...          % modelo nominal
                                        d_hat_prev);

        Tau_total(i, :)  = tau_total(:)';
        d_hat_hist(i, :) = d_hat(:)';

        d_hat_prev = d_hat;
    end

    % =============================
    % 7) SALIDA FINAL
    % =============================
    TrayFinalDinamica = [TrayArt(:,1:3), Q_dot, Q_ddot, Tau_total];

    fprintf(' Dinamica completada. Salida = [%d x %d]\n', ...
            size(TrayFinalDinamica,1), size(TrayFinalDinamica,2));
end
