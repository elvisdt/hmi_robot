%% MainScaraMulticuerpo.m
% =============================================================
% SIMULACION SCARA P-R-R (DINAMICA DIRECTA - LAZO CERRADO CTC+DOB)
% =============================================================
clc; clear; close all;
fprintf('======================================================\n');
fprintf('   SIMULACION SCARA P-R-R (DINAMICA DIRECTA/CONTROL)\n');
fprintf('======================================================\n');
%% -------------------- 1) Parametros Fisicos y Dinamicos (SI Units) --------------------
% --- Parametros Cinematicos y Dinamicos ---
params.L1 = 0.600;    % [m] Longitud Brazo 1
params.L2 = 0.580;    % [m] Longitud Brazo 2
params.g  = 9.81;     % [m/s^2]
params.m1 = 3.0;      % [kg] Masa eslabon 1 (Prismatico)
params.m2 = 2.93;     % [kg] Masa eslabon 2 (Hombro)
params.m3 = 1.89;     % [kg] Masa eslabon 3 (Codo)
params.I2 = 0.10;     % [kgm^2] Inercia eslabon 2
params.I3 = 0.05;     % [kgm^2] Inercia eslabon 3
% --- Parametros de Disipacion y Carga ---
params.B  = [5; 0.15; 0.15];   % Coef. Viscosa Articulares [N.s/m; Nm.s/rad; Nm.s/rad]
params.F_ext = [0.5; 0.5; 8];  % Carga externa de la herramienta [N]
% --- Parametros de Centro de Masa ---
params.lc2 = 0.3 * params.L1; 
params.lc3 = 0.3 * params.L2; 
fprintf('    Parametros Fisicos definidos.\n');
% Limites Tipicos de un SCARA:
params.Qdot_max  = [1.0; 4.0; 4.0]; 
params.Qddot_max = [5.0; 30.0; 30.0]; 


%% -------------------- 2) Parametros de Operacion y Control -----------------
Z_home         = 310;   % [mm] Altura de traslado
Z_cut          = 270;   % [mm] Altura de corte
Speed_traslado = 45000; % [mm/min]
ratio          = 0.05;
Speed_cut      = ratio*Speed_traslado; 
% Definicion Cartesiana HOME (mm)
X_home_mm = 70.46; 
Y_home_mm = 155.28;
Z_home_mm = Z_home; 
P_home_cart_mm = [X_home_mm, Y_home_mm, Z_home_mm]; 

% Parametros de Muestreo y Tiempo
params.paso = 0.05;      % [mm] Resolucion espacial
params.Fs   = 2000;      % [Hz] Frecuencia de muestreo
params.dt   = 1/params.Fs; % Paso de tiempo
A_max_cart = 5000;       % [mm/s^2] Aceleracion cartesiana maxima
params.SpeedUp_Factor = 1.0; 
% --- GANANCIAS DEL CONTROLADOR PD (PARA CTC) ---
params.Kp = 100 * eye(3);  
params.Kv = 20 * eye(3);   
%  PARAMETROS DEL OBSERVADOR DE PERTURBACIONES (DOB)
params.DOB_w0 = 50; % [rad/s] Frecuencia de corte del filtro (Tuning critico)
params.Ts     = params.dt; % Paso de tiempo para el filtro DOB
%  PARAMETROS CRITICOS PARA LA SIMULACION DE CONTROL
params.m_error_factor = 1.5; % Factor de error parametrico (1.5 = 50% de error en masa)
fprintf('    Parametros de Control: Fs=%d Hz (dt=%.4fs). Factor Error Masa = %.1f. DOB_w0 = %d rad/s\n', params.Fs, params.dt, params.m_error_factor, params.DOB_w0);


%% -------------------- 3) ORQUESTACION DEL PIPELINE CINEMATICO -------------------------
fprintf('\n\n--- FASE 1: PLANIFICACION Y CINEMATICA INVERSA (Referencias) ---\n');
% 3.1. LECTURA E INTERPOLACION CARTESIANA
grupos = LeerTrayectoria();  
grupos_con_guardado = PosicionGuardado(grupos, P_home_cart_mm, Z_home_mm);
TrayectoriaInterpolada = InterpolarTrayectoria(grupos_con_guardado, params.paso, Z_cut);
% 3.2. PLANIFICACION Z y PERFILADO DE VELOCIDADES
fprintf('   1. Llamando a PlanificarTrayectoria.m (Perfil Trapezoidal)...\n');
TrayFinal = PlanificarTrayectoria(TrayectoriaInterpolada, Z_home, Z_cut, params.paso, Speed_cut, Speed_traslado, A_max_cart);
fprintf('    Trayectoria final planificada (len=%d) con velocidad perfilada.\n', size(TrayFinal,1));
% 3.3. CINEMATICA INVERSA (POSICIONES DESEADAS)
fprintf('   2. Llamando a CinematicaInversa.m (Conversion a coordenadas articulares)...\n');
TrayArt = CinematicaInversa(TrayFinal(:, 1:3), params.L1, params.L2, TrayFinal(:, 4:5));
% 3.4. CALCULO DE VELOCIDAD, ACELERACION Y TIEMPO (REFERENCIA)
fprintf('   3. Calculando Referencias de Velocidad y Aceleracion Articular...\n');
[Q_dot_d, Q_ddot_d, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params);
Q_d = TrayArt(:, 1:3); % Posiciones deseadas
fprintf('    Referencias Q, Qdot, Qddot calculadas (Duracion total: %.2f s).\n', Tiempos(end));


%% -------------------- FASE 2: SIMULACION DE CONTROL EN LAZO CERRADO (ODE45) --------------------
fprintf('\n--- FASE 2: SIMULACION DE CONTROL (ODE45 CTC + DOB) ---\n');
% 4.1. Preparar Referencias para Interpolacion
Q_ref      = Q_d;        
Q_dot_ref  = Q_dot_d;    
Q_ddot_ref = Q_ddot_d;   
Tiempo_ref = Tiempos; 
% 4.2. Condiciones Iniciales Reales (ESTADO EXTENDIDO)
% X = [q1:3; dq1:3; d_hat1:3] -> 9 estados
x0 = [Q_ref(1, :)'; Q_dot_ref(1, :)']; 
d_hat_init = zeros(3,1); % Inicializamos la estimacion de perturbacion a cero
x0_ext = [x0; d_hat_init]; 

% 4.3. Ejecutar ODE45
fprintf('    Ejecutando ODE45 (Simulando fisica real vs control)...\n');
options = odeset('RelTol', 1e-4, 'AbsTol', 1e-4);
% CAMBIAMOS A LA NUEVA FUNCION!
[t_sim, x_sim_ext] = ode45(@(t,x) SistemaDinamico_DOB(t, x, params, Q_ref, Q_dot_ref, Q_ddot_ref, Tiempo_ref), ...
                       [Tiempo_ref(1) Tiempo_ref(end)], x0_ext, options);
fprintf('    Simulacion completada. %d puntos de datos generados.\n', size(t_sim, 1));


%% -------------------- FASE 3: EXTRACCION Y GRAFICOS --------------------
fprintf('\n--- FASE 3: RESULTADOS, GRAFICAS Y ANIMACION ---\n');
% 5.1. Extraer Posiciones Reales (Simuladas) del estado extendido
q_sim     = x_sim_ext(:, 1:3);   % Posicion Real q(t)
dq_sim    = x_sim_ext(:, 4:6);   % Velocidad Real dq(t)
d_hat_sim = x_sim_ext(:, 7:9);   % Estimacion de la perturbacion (DOB)

% 5.2. Extraer Referencia para Comparacion
q_ref_interp = interp1(Tiempo_ref, Q_ref, t_sim);
dq_ref_interp = interp1(Tiempo_ref, Q_dot_ref, t_sim);
% 5.3. CALCULO DEL ERROR 
Error = q_ref_interp - q_sim;
figure;
subplot(3,1,1);
plot(t_sim, Error(:,1));
ylabel('$e_1 (m)$', 'Interpreter', 'latex');
title('Error Articular de Posicion'); % Este título no requiere LaTeX, pero se puede añadir si se desea
grid on;

subplot(3,1,2);
plot(t_sim, Error(:,2));
ylabel('$e_2 (rad)$', 'Interpreter', 'latex');
grid on;

subplot(3,1,3);
plot(t_sim, Error(:,3));
ylabel('$e_3 (rad)$', 'Interpreter', 'latex');
xlabel('Tiempo (s)');
grid on;

sgtitle(['Errores de Seguimiento (CTC + DOB. Factor Masa = ' num2str(params.m_error_factor) ')'], 'Interpreter', 'latex');

fprintf('    Grafica de errores generada. Deberias ver un error muy reducido gracias al DOB.\n');

% 5.4. GRAFICAR ESTIMACION DE PERTURBACIONES (DOB)
figure;
subplot(3,1,1); 
plot(t_sim, d_hat_sim(:,1));
ylabel('$d_1 (\tau)$', 'Interpreter', 'latex');
title('Estimacion de Perturbacion ($\hat{d}$) - DOB', 'Interpreter', 'latex');
grid on;

subplot(3,1,2);
plot(t_sim, d_hat_sim(:,2));
ylabel('$\theta_2 (\tau)$', 'Interpreter', 'latex');
grid on;

subplot(3,1,3);
plot(t_sim, d_hat_sim(:,3));
ylabel('$\theta_3 (\tau)$', 'Interpreter', 'latex');
xlabel('Tiempo (s)');
grid on;
sgtitle('Salida del Observador de Perturbaciones (DOB)', 'Interpreter', 'latex');



% 5.5. GRAFICAR SEGUIMIENTO (SetPoint vs Respuesta Real)
figure;
subplot(3,1,1);
plot(t_sim, q_ref_interp(:,1), 'b--', t_sim, q_sim(:,1), 'r-');
ylabel('$d_1 (m)$', 'Interpreter', 'latex');
title('Seguimiento de Posicion Articular');
legend('Referencia', 'Respuesta Real');
grid on;

subplot(3,1,2);
plot(t_sim, q_ref_interp(:,2), 'b--', t_sim, q_sim(:,2), 'r-');
ylabel('$\theta_2 (rad)$', 'Interpreter', 'latex');
grid on;

subplot(3,1,3);
plot(t_sim, q_ref_interp(:,3), 'b--', t_sim, q_sim(:,3), 'r-');
ylabel('$\theta_3 (rad)$', 'Interpreter', 'latex');
xlabel('Tiempo (s)');
grid on;


% 5.6. ANIMACION (Usando el resultado real de la simulacion)
fprintf('    Animando trayectoria real (simulada)...\n');
TrayArt_sim = [q_sim, ones(size(q_sim,1), 2)]; % Columnas 4 y 5 son flags/V dummy
AnimarTrayectoria(TrayArt_sim, params.L1, params.L2, t_sim, params.SpeedUp_Factor,3,0.26);
fprintf('\n--- SIMULACION FINALIZADA ---\n');

% -------------------------------------------------------------
% MANTENEMOS FUNCIONES AUXILIARES NECESARIAS:
% Jacobiano, DiferenciarTrayectoriaArticular, ControlCTC, ModeloDin, perturbaciones
% *Las funciones Dinamica.m, Torques.m y DOB_Update.m fueron eliminadas/reemplazadas*
% -------------------------------------------------------------
% [Anadir las funciones Jacobiano, DiferenciarTrayectoriaArticular, ControlCTC, ModeloDin, perturbaciones aqui]