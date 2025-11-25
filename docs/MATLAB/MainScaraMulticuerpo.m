%% MainScaraMulticuerpo.m
% =============================================================
% SIMULACIÓN SCARA P-R-R (DINÁMICA INVERSA)
% Orquestación: planificación (suavizado) -> cinemática inversa -> dinámica -> gráficas -> animación
% =============================================================
clc; clear; close all;
fprintf('======================================================\n');
fprintf('  🤖 SIMULACIÓN SCARA P-R-R (DINÁMICA INVERSA)        \n');
fprintf('======================================================\n');

%% -------------------- 1) Parámetros Físicos y Dinámicos (SI Units) --------------------
% --- Parámetros Cinemáticos y Dinámicos ---
params.L1 = 0.650;    % [m] Longitud Brazo 1
params.L2 = 0.600;    % [m] Longitud Brazo 2
params.g  = 9.81;     % [m/s^2]
params.m1 = 5.0;      % [kg] Masa eslabón 1 (Prismático)
params.m2 = 1.8;      % [kg] Masa eslabón 2 (Hombro)
params.m3 = 1.2;      % [kg] Masa eslabón 3 (Codo)
params.I2 = 0.10;     % [kg·m^2] Inercia eslabón 2
params.I3 = 0.05;     % [kg·m^2] Inercia eslabón 3

% --- Parámetros de Disipación y Carga ---
params.B  = [5; 0.15; 0.15];   % Coef. Viscosa Articulares [N.s/m; Nm.s/rad; Nm.s/rad]
params.F_ext = [0.5; 0.5; 8];      % Carga externa de la herramienta [N]

% --- Parámetros de Centro de Masa (Añadir al modelo dinámico si no están implícitos) ---
% Se añaden para que ModeloDin pueda acceder a ellos si es necesario
params.lc2 = 0.3 * params.L1; % Centro de masa estimado de L1
params.lc3 = 0.3 * params.L2; % Centro de masa estimado de L2

fprintf('   ✅ Parámetros Físicos y Dinámicos definidos.\n');

% --- AÑADIR ESTO A LA SECCIÓN 1 DE MainScaraMulticuerpo.m ---
% Límites Típicos de un SCARA:
params.Qdot_max  = [1.0; 4.0; 4.0];  % [m/s, rad/s, rad/s] Velocidad máxima
params.Qddot_max = [5.0; 30.0; 30.0]; % [m/s^2, rad/s^2, rad/s^2] Aceleración máxima

%% -------------------- 2) Parámetros de Operación y Control -----------------
Z_home         = 200;   % [mm] Altura de traslado
Z_cut          = 150;   % [mm] Altura de corte
Speed_traslado = 45000; % [mm/min]
ratio          = 0.05;
Speed_cut      = ratio*Speed_traslado; % [mm/min]

%% --- DEFINICIÓN CARTESIANA HOME-----------------------
% (Guardado/Reposo)--------------------------
% P_home = [X, Y, Z] en milímetros. 
% Calculado para d1=200mm, th2=0, th3=30 deg.
X_home_mm = 70.46; 
Y_home_mm = 155.28;
Z_home_mm = Z_home; % 200 mm

P_home_cart_mm = [X_home_mm, Y_home_mm, Z_home_mm]; % [mm]

% Parámetros de Muestreo, Interpolación y Perfilado
params.paso = 0.05;                % [mm] Resolución espacial para interpolación
params.Fs   = 2000;              % [Hz] Frecuencia de muestreo/Simulación
% ¡Importante! Usamos tu valor de A_max para PlanificarTrayectoria
A_max_cart = 5000;              % [mm/s^2] Aceleración cartesiana máxima (para perfil trapezoidal)

% Factor de Aceleración de Visualización
params.SpeedUp_Factor = 1.0; % Visualización 100x más rápida

fprintf('   ⚙️ Parámetros de Operación definidos: V_traslado=%.0f mm/min, A_max_cart=%.0f mm/s^2\n', Speed_traslado, A_max_cart);

%% -------------------- 3) ORQUESTACIÓN DEL PIPELINE -------------------------
fprintf('\n\n--- FASE 1: PLANIFICACIÓN Y CINEMÁTICA ---\n');
% 3.1. LECTURA E INTERPOLACIÓN
% (Asumimos que esta fase genera la lista de puntos X, Y, Z cartesiana)
grupos = LeerTrayectoria();  % -> celda de grupos { [X Y Z CORTAR] }

% 1. Añadimos los Flags de Guardado (2 y 3) y la Z_home a la trayectoria bruta
grupos_con_guardado = PosicionGuardado(grupos, P_home_cart_mm, Z_home_mm);

% 2. INTERPOLACIÓN CLAVE: Se pasa Z_cut para asegurar la altura de trabajo 
%    (corrige el problema del Z=0)
TrayectoriaInterpolada = InterpolarTrayectoria(grupos_con_guardado, params.paso, Z_cut); % <--- ¡CORRECCIÓN AQUÍ!
% Asumimos que genera una matriz [X Y Z] en [mm]

% 3.2. PLANIFICACIÓN Z y PERFILADO DE VELOCIDADES
% TrayFinal: [X(m), Y(m), Z(m), FLAG, V_PERFILADA(m/s)]
fprintf('   1. Llamando a PlanificarTrayectoria.m (Perfil Trapezoidal)...\n');
TrayFinal = PlanificarTrayectoria(TrayectoriaInterpolada, Z_home, Z_cut, params.paso, Speed_cut, Speed_traslado, A_max_cart);
fprintf('   🟢 Trayectoria final planificada (len=%d) con velocidad perfilada.\n', size(TrayFinal,1));

% 3.3. CINEMÁTICA INVERSA
% Pasa las posiciones cartesianas y retorna la matriz articular: [d1 th2 th3 flag V]
fprintf('   2. Llamando a CinematicaInversa.m (Conversión a coordenadas articulares)...\n');
% Nota: Es crucial que CinematicaInversa mantenga las columnas 4 y 5 (flag, V_perfilada) intactas.
TrayArt = CinematicaInversa(TrayFinal(:, 1:3), params.L1, params.L2, TrayFinal(:, 4:5));

fprintf('\n\n--- FASE 2: DINÁMICA INVERSA Y CÁLCULO DE TIEMPO ---\n');

% 3.4. CÁLCULO DINÁMICO COMPLETO (ORQUESTADO)
% La función Dinamica llama internamente a DiferenciarTrayectoriaArticular para obtener T, Q_dot y Q_ddot.
fprintf('   3. Llamando a Dinamica.m (Cálculo de Qdot, Qddot y Torques Tau)...\n');
% TrayFinalDinamica: [q | dq | ddq | tau]
TrayFinalDinamica = Dinamica(TrayArt, params); 
fprintf('   ✅ Cálculo Dinámico Completo. Matriz de salida lista.\n');

%% -------------------- 4) EXTRACCIÓN, GRÁFICOS Y ANIMACIÓN --------------------

% 4.1. Recalcular Tiempos (Necesario ya que Dinamica no devuelve Tiempos directamente)
% Llamamos a la función de diferenciación *solamente* para extraer el vector de Tiempos acumulado.
[~, ~, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params);
fprintf('   ⏱️ Vector de Tiempos extraído para gráficas/animación (Duración total: %.2f s).\n', Tiempos(end));

% 4.2. EXTRACCIÓN Y GRÁFICOS
tau_SCARA = TrayFinalDinamica(:, 10:12);
dq_hist   = TrayFinalDinamica(:, 4:6);
GraficarTorques(TrayFinalDinamica, Tiempos, params); % <-- Asume función GraficarTorques()
fprintf('   📊 Gráficos de Dinámica (Torque vs. Tiempo) generados.\n');

% 4.3. ANIMACIÓN
fprintf('   4. Llamando a AnimarTrayectoria.m (Visualización con factor x%.0f)...\n', params.SpeedUp_Factor);
AnimarTrayectoria(TrayArt, params.L1, params.L2, Tiempos, params.SpeedUp_Factor);

fprintf('\n--- SIMULACIÓN FINALIZADA ---\n');