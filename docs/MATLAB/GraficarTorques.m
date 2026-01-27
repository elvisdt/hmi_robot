function GraficarTorques(TrayFinalDinamica, Tiempos, params)
% GRAFICARTORQUES - Genera los graficos de Torque/Fuerza, Velocidad y Aceleracion para la seleccion de actuadores.
% Entradas:
%   TrayFinalDinamica - Matriz Nx12 [q, dq, ddq, tau]
%   Tiempos           - Vector de tiempo (s)
%   params            - Estructura de parametros
    
    % Extraccion de datos
    Q_dot = TrayFinalDinamica(:, 4:6);    % [d_dot1, th_dot2, th_dot3]
    Q_ddot = TrayFinalDinamica(:, 7:9);   % [d_ddot1, th_ddot2, th_ddot3]
    Tau = TrayFinalDinamica(:, 10:12);    % [tau1, tau2, tau3]
    
    titulos = {'Articulacion 1 (Prismatica)', ...
               'Articulacion 2 (Rotativa)', ...
               'Articulacion 3 (Rotativa)'};
    
    unidades_fuerza = {'Fuerza [N]', 'Torque [Nm]', 'Torque [Nm]'};
    

    unidades_vel    = {'Velocidad $\dot{d}_1$ [m/s]', 'Velocidad $\dot{\theta}_2$ [rad/s]', 'Velocidad $\dot{\theta}_3$ [rad/s]'};
    unidades_acel   = {'Aceleracion $\ddot{d}_1$ [m/s$^2$]', 'Aceleracion $\ddot{\theta}_2$ [rad/s$^2$]', 'Aceleracion $\ddot{\theta}_3$ [rad/s$^2$]'};
  
    % Calcular Metricas Clave
    tau_rms = sqrt(mean(Tau.^2, 1));
    tau_pico = max(abs(Tau), [], 1);
    
    fig = figure('Name', 'Resultados Dinamicos SCARA P-R-R', 'Position', [50 50 1600 800]);
    t = tiledlayout(fig, 3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
    
    for i = 1:3
        % --- GRAFICO 1: Torque vs. Velocidad (CURVA DE POTENCIA/MOTOR) ---
        nexttile((i-1)*4 + 1);
        plot(Q_dot(:,i), Tau(:,i), 'c.', 'DisplayName', 'Operacion');
        hold on;
        vel_min = min(Q_dot(:,i));
        vel_max = max(Q_dot(:,i));
        line([vel_min, vel_max], [tau_pico(i), tau_pico(i)], 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Pico');
        line([vel_min, vel_max], [-tau_pico(i), -tau_pico(i)], 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off'); 
        line([vel_min, vel_max], [tau_rms(i), tau_rms(i)], 'Color', 'm', 'LineStyle', ':', 'DisplayName', 'RMS');
        line([vel_min, vel_max], [-tau_rms(i), -tau_rms(i)], 'Color', 'm', 'LineStyle', ':', 'HandleVisibility', 'off');
    
        xlabel('Velocidad $\dot{q}$ [m/s o rad/s]', 'Interpreter', 'latex'); 

        ylabel('$\tau$ [N o Nm]', 'Interpreter', 'latex');
        % Cambio: Usar sprintf para titulo, y añadir 'Interpreter', 'latex'
        title(sprintf('%s: $\\tau$ vs $\\dot{q}$', titulos{i}), 'Interpreter', 'latex');
        legend('Location', 'best'); grid on;
        
        % --- GRAFICO 2: Torque/Fuerza vs. Tiempo ---
        nexttile((i-1)*4 + 2);
        plot(Tiempos, Tau(:,i), 'b-', 'LineWidth', 1.2);
        hold on;
        plot(Tiempos, ones(size(Tiempos))*tau_rms(i), 'm:', 'DisplayName', 'RMS');
        plot(Tiempos, ones(size(Tiempos))*(-tau_rms(i)), 'm:', 'HandleVisibility', 'off');
        plot(Tiempos, ones(size(Tiempos))*tau_pico(i), 'r--', 'DisplayName', 'Pico');
        plot(Tiempos, ones(size(Tiempos))*(-tau_pico(i)), 'r--', 'HandleVisibility', 'off');
        xlabel('Tiempo [s]');
        ylabel(unidades_fuerza{i}); % No contiene LaTeX, no necesita cambio de interprete
        % Cambio: Usar sprintf para titulo, y añadir 'Interpreter', 'latex'
        title(sprintf('%s: $\\tau(t)$', titulos{i}), 'Interpreter', 'latex');
        legend('Location', 'best'); grid on;
        
        % --- GRAFICO 3: Velocidad Articular vs. Tiempo (Validacion de Perfil Suave) ---
        nexttile((i-1)*4 + 3);
        plot(Tiempos, Q_dot(:,i), 'g-', 'LineWidth', 1.2);
        xlabel('Tiempo [s]');
        ylabel(unidades_vel{i}, 'Interpreter', 'latex');
        title(sprintf('%s: $\\dot{q}(t)$', titulos{i}), 'Interpreter', 'latex');
        grid on;
        
        % --- GRAFICO 4: Aceleracion Articular vs. Tiempo (Validacion de Suavidad) ---
        nexttile((i-1)*4 + 4);
        plot(Tiempos, Q_ddot(:,i), 'k-', 'LineWidth', 1.2); 
        xlabel('Tiempo [s]');
        ylabel(unidades_acel{i}, 'Interpreter', 'latex');
        title(sprintf('%s: $\\ddot{q}(t)$', titulos{i}), 'Interpreter', 'latex');
        grid on;
    end
    title(t, 'Analisis Dinamico Completo (SCARA P-R-R)', 'FontSize', 14, 'FontWeight', 'bold');
end