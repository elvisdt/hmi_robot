function GraficarTorques(TrayFinalDinamica, Tiempos, params)
% GRAFICARTORQUES - Genera los gr  ficos de Torque/Fuerza, Velocidad y Aceleraci  n para la selecci  n de actuadores.
% Entradas:
%   TrayFinalDinamica - Matriz Nx12 [q, dq, ddq, tau]
%   Tiempos           - Vector de tiempo (s)
%   params            - Estructura de par  metros
    
    % Extracci  n de datos
    Q_dot = TrayFinalDinamica(:, 4:6);    % [d_dot1, th_dot2, th_dot3]
    Q_ddot = TrayFinalDinamica(:, 7:9);   % [d_ddot1, th_ddot2, th_ddot3]
    Tau = TrayFinalDinamica(:, 10:12);    % [tau1, tau2, tau3]
    
    titulos = {'Articulaci  n 1 (Prism  tica)', ...
               'Articulaci  n 2 (Rotativa)', ...
               'Articulaci  n 3 (Rotativa)'};
    
    unidades_fuerza = {'Fuerza [N]', 'Torque [Nm]', 'Torque [Nm]'};
    
    % *** SINTAXIS CORREGIDA (TeX por defecto) ***
    unidades_vel    = {'Velocidad d1 [m/s]', 'Velocidad theta2 [rad/s]', 'Velocidad theta3 [rad/s]'};
    unidades_acel   = {'Aceleracion d1 [m/s^2]', 'Aceleracion theta2 [rad/s^2]', 'Aceleracion theta3 [rad/s^2]'};
    % *********************************************
    
    % Calcular M  tricas Clave
    tau_rms = sqrt(mean(Tau.^2, 1));
    tau_pico = max(abs(Tau), [], 1);
    
    figure('Name', 'Resultados Din  micos SCARA P-R-R', 'Position', [50 50 1600 800]);
    
    for i = 1:3
        % --- GR  FICO 1: Torque vs. Velocidad (CURVA DE POTENCIA/MOTOR) ---
        subplot(3, 4, 4*(i-1) + 1);
        plot(Q_dot(:,i), Tau(:,i), 'c.', 'DisplayName', 'Operaci  n');
        hold on;
        
        % Dibujar L  mites Pico y RMS
        % CORRECCI  N: Usar los l  mites de velocidad del eje X para dibujar los l  mites de torque Y
        vel_min = min(Q_dot(:,i));
        vel_max = max(Q_dot(:,i));
        
        % L  nea Pico Positivo
        line([vel_min, vel_max], [tau_pico(i), tau_pico(i)], 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Pico Absoluto');
        % L  nea Pico Negativo (Para cubrir todo el espacio, aunque solo se nombre la positiva)
        line([vel_min, vel_max], [-tau_pico(i), -tau_pico(i)], 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off'); 
        
        % L  nea RMS
        line([vel_min, vel_max], [tau_rms(i), tau_rms(i)], 'Color', 'm', 'LineStyle', ':', 'DisplayName', 'RMS');
        
        % L  nea -RMS
        line([vel_min, vel_max], [-tau_rms(i), -tau_rms(i)], 'Color', 'm', 'LineStyle', ':', 'HandleVisibility', 'off');
        
        xlabel('Velocidad Articular qdot [m/s o rad/s]'); 
        ylabel('Torque/Fuerza \tau [N o Nm]');
        title(sprintf('%s (Pico: %.2f | RMS: %.2f)', titulos{i}, tau_pico(i), tau_rms(i)));
        legend('Location', 'best');
        grid on;
        
        % --- GR  FICO 2: Torque/Fuerza vs. Tiempo ---
        subplot(3, 4, 4*(i-1) + 2);
        plot(Tiempos, Tau(:,i), 'b-', 'LineWidth', 1.2);
        hold on;
        
        % A  adir l  nea RMS, -RMS, Pico y -Pico
        plot(Tiempos, ones(size(Tiempos))*tau_rms(i), 'm:', 'DisplayName', 'RMS');
        plot(Tiempos, ones(size(Tiempos))*(-tau_rms(i)), 'm:', 'HandleVisibility', 'off');
        
        plot(Tiempos, ones(size(Tiempos))*tau_pico(i), 'r--', 'DisplayName', 'Pico');
        plot(Tiempos, ones(size(Tiempos))*(-tau_pico(i)), 'r--', 'HandleVisibility', 'off');
        
        xlabel('Tiempo [s]');
        ylabel(unidades_fuerza{i});
        title(sprintf('%s: Perfil de Torque/Fuerza', titulos{i}));
        grid on;
        
        % --- GR  FICO 3: Velocidad Articular vs. Tiempo (Validaci  n de Perfil Suave) ---
        subplot(3, 4, 4*(i-1) + 3);
        plot(Tiempos, Q_dot(:,i), 'g-', 'LineWidth', 1.2);
        
        xlabel('Tiempo [s]');
        ylabel(unidades_vel{i});
        title(sprintf('%s: Perfil de Velocidad', titulos{i}));
        grid on;
        
        % --- GR  FICO 4: Aceleraci  n Articular vs. Tiempo (Validaci  n de Suavidad) ---
        subplot(3, 4, 4*(i-1) + 4);
        % CORRECCI  N: Cambio de color de l  nea a negro ('k-') para que sea visible.
        plot(Tiempos, Q_ddot(:,i), 'w-', 'LineWidth', 1.2); 
        
        xlabel('Tiempo [s]');
        ylabel(unidades_acel{i});
        title(sprintf('%s: Perfil de Aceleraci  n', titulos{i}));
        grid on;
        
    end
    sgtitle('An  lisis Din  mico Completo (SCARA P-R-R)', 'FontSize', 14, 'FontWeight', 'bold');
end
