function TrayFinalDinamica = Dinamica(TrayArt, params)
% DINAMICA - Funcion principal que coordina el calculo dinamico COMPLETO.
%
% ENTRADAS:
%   TrayArt  - Nx5 [d1 th2 th3 flag V] (Posiciones articulares precalculadas)
%   params   - Estructura de parametros del robot (Debe incluir L1, L2, Fs, y parametros dinamicos)
%
% SALIDA:
%   TrayFinalDinamica - Nx9 matriz con [d1 th2 th3 | d_dot1 th_dot2 th_dot3 | d_ddot1 th_ddot2 th_ddot3 | tau1 tau2 tau3]
%
% LLAMA A: DiferenciarTrayectoriaArticular.m, Torques.m
    
    num_puntos = size(TrayArt, 1);
    
    % --- 1. Calcular Perfiles de Velocidad y Aceleracion ARTICULAR ---
    fprintf('   1. Llamando a DiferenciarTrayectoriaArticular.m (Perfil y Diferenciacion)...\n');
    
    % *** REEMPLAZO de la linea original ***
    [Q_dot, Q_ddot, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params);
    
    % --- 2. Preparar Matriz de Salida de Torques ---
    Tau = zeros(num_puntos, 3);
    
    % --- 3. Bucle Principal: Dinamica Inversa ---
    fprintf('   2. Ejecutando Bucle de Dinamica Inversa...\n');
    for i = 1:num_puntos
        % Vectores de estado
        q = TrayArt(i, 1:3)'; 
        
        % Obtener la Velocidad y Aceleracion del perfil suave
        dq = Q_dot(i, :)';    
        ddq = Q_ddot(i, :)';  
        
        % --- CALCULO DINAMICO INVERSO ---
        
        % 3.1. Calcular Torques Requeridos
        tau = Torques(q, dq, ddq, params); % <<-- M(q)ddq + C(q,dq)dq + G(q)
        Tau(i, :) = tau';
    end
    
    % --- 4. Concatenacion de la Salida Final ---
    % Salida: [d1 th2 th3 | d_dot1 th_dot2 th_dot3 | d_ddot1 th_ddot2 th_ddot3 | tau1 tau2 tau3]
    TrayFinalDinamica = [TrayArt(:, 1:3), Q_dot, Q_ddot, Tau]; 
    
    fprintf('    Dinamica (Estructura Inversa) finalizada y lista para la simulacion.\n');
end