%% MainScaraMulticuerpo.m
% =============================================================
% SIMULACI  N SCARA P-R-R (DIN  MICA INVERSA)
% Orquestaci  n: planificaci  n (suavizado) -> cinem  tica inversa -> din  mica -> gr  ficas -> animaci  n
% =============================================================
clc; clear; close all;
fprintf('======================================================\n');
fprintf('       SIMULACION SCARA P-R-R (DIN  MICA INVERSA)        \n');
fprintf('======================================================\n');

%% -------------------- 1) Par  metros F  sicos y Din  micos (SI Units) --------------------
% --- Par  metros Cinem  ticos y Din  micos ---
params.L1 = 0.650;    % [m] Longitud Brazo 1
params.L2 = 0.600;    % [m] Longitud Brazo 2
params.g  = 9.81;     % [m/s^2]
params.m1 = 5.0;      % [kg] Masa eslab  n 1 (Prism  tico)
params.m2 = 1.8;      % [kg] Masa eslab  n 2 (Hombro)
params.m3 = 1.2;      % [kg] Masa eslab  n 3 (Codo)
params.I2 = 0.10;     % [kg  m^2] Inercia eslab  n 2
params.I3 = 0.05;     % [kg  m^2] Inercia eslab  n 3

% --- Par  metros de Disipaci  n y Carga ---
params.B  = [5; 0.15; 0.15];   % Coef. Viscosa Articulares [N.s/m; Nm.s/rad; Nm.s/rad]
params.F_ext = [0.5; 0.5; 8];      % Carga externa de la herramienta [N]

% --- Par  metros de Centro de Masa (A  adir al modelo din  mico si no est  n impl  citos) ---
% Se a  aden para que ModeloDin pueda acceder a ellos si es necesario
params.lc2 = 0.3 * params.L1; % Centro de masa estimado de L1
params.lc3 = 0.3 * params.L2; % Centro de masa estimado de L2

fprintf('       Par  metros F  sicos y Din  micos definidos.\n');

% --- A  ADIR ESTO A LA SECCI  N 1 DE MainScaraMulticuerpo.m ---
% L  mites T  picos de un SCARA:
params.Qdot_max  = [1.0; 4.0; 4.0];  % [m/s, rad/s, rad/s] Velocidad m  xima
params.Qddot_max = [5.0; 30.0; 30.0]; % [m/s^2, rad/s^2, rad/s^2] Aceleraci  n m  xima

%% -------------------- 2) Par  metros de Operaci  n y Control -----------------
Z_home         = 200;   % [mm] Altura de traslado
Z_cut          = 150;   % [mm] Altura de corte
Speed_traslado = 45000; % [mm/min]
ratio          = 0.05;
Speed_cut      = ratio*Speed_traslado; % [mm/min]

%% --- DEFINICI  N CARTESIANA HOME-----------------------
% (Guardado/Reposo)--------------------------
% P_home = [X, Y, Z] en mil  metros. 
% Calculado para d1=200mm, th2=0, th3=30 deg.
X_home_mm = 70.46; 
Y_home_mm = 155.28;
Z_home_mm = Z_home; % 200 mm

P_home_cart_mm = [X_home_mm, Y_home_mm, Z_home_mm]; % [mm]

% Par  metros de Muestreo, Interpolaci  n y Perfilado
params.paso = 0.05;                % [mm] Resoluci  n espacial para interpolaci  n
params.Fs   = 2000;              % [Hz] Frecuencia de muestreo/Simulaci  n
%   Importante! Usamos tu valor de A_max para PlanificarTrayectoria
A_max_cart = 5000;              % [mm/s^2] Aceleraci  n cartesiana m  xima (para perfil trapezoidal)

% Factor de Aceleraci  n de Visualizaci  n
params.SpeedUp_Factor = 1.0; % Visualizaci  n 100x m  s r  pida

fprintf('Para metros de Operaci  n definidos: V_traslado=%.0f mm/min, A_max_cart=%.0f mm/s^2\n', Speed_traslado, A_max_cart);

%% -------------------- 3) ORQUESTACI  N DEL PIPELINE -------------------------
fprintf('\n\n--- FASE 1: PLANIFICACION Y CINEMATICA ---\n');
% 3.1. LECTURA DE INTERPOLACION
% (Asumimos que esta fase genera la lista de puntos X, Y, Z cartesiana)
grupos = LeerTrayectoria();  % -> celda de grupos { [X Y Z CORTAR] }

% 1. A  adimos los Flags de Guardado (2 y 3) y la Z_home a la trayectoria bruta
grupos_con_guardado = PosicionGuardado(grupos, P_home_cart_mm, Z_home_mm);

% 2. INTERPOLACI  N CLAVE: Se pasa Z_cut para asegurar la altura de trabajo 
%    (corrige el problema del Z=0)
TrayectoriaInterpolada = InterpolarTrayectoria(grupos_con_guardado, params.paso, Z_cut); % <---   CORRECCI  N AQU  !
% Asumimos que genera una matriz [X Y Z] en [mm]

% 3.2. PLANIFICACI  N Z y PERFILADO DE VELOCIDADES
% TrayFinal: [X(m), Y(m), Z(m), FLAG, V_PERFILADA(m/s)]
fprintf('   1. Llamando a PlanificarTrayectoria.m (Perfil Trapezoidal)...\n');
TrayFinal = PlanificarTrayectoria(TrayectoriaInterpolada, Z_home, Z_cut, params.paso, Speed_cut, Speed_traslado, A_max_cart);
fprintf('        Trayectoria final planificada (len=%d) con velocidad perfilada.\n', size(TrayFinal,1));

% 3.3. CINEM  TICA INVERSA
% Pasa las posiciones cartesianas y retorna la matriz articular: [d1 th2 th3 flag V]
fprintf('   2. Llamando a CinematicaInversa.m (Conversion a coordenadas articulares)...\n');
% Nota: Es crucial que CinematicaInversa mantenga las columnas 4 y 5 (flag, V_perfilada) intactas.
TrayArt = CinematicaInversa(TrayFinal(:, 1:3), params.L1, params.L2, TrayFinal(:, 4:5));

fprintf('\n\n--- FASE 2: DINAMICA INVERSA Y CALCULO DE TIEMPO ---\n');

% 3.4. CALCULO DINAMICO COMPLETO (ORQUESTADO)
% La funcion Dinamica llama internamente a DiferenciarTrayectoriaArticular para obtener T, Q_dot y Q_ddot.
fprintf('   3. Llamando a Dinamica.m (Calculo de Qdot, Qddot y Torques Tau)...\n');
% TrayFinalDinamica: [q | dq | ddq | tau]
TrayFinalDinamica = Dinamica(TrayArt, params); 
fprintf('       Calculo Dinamico Completo. Matriz de salida lista.\n');

%% -------------------- 4) EXTRACCION, GRAFICOS Y ANIMACION --------------------

% 4.1. Recalcular Tiempos (Necesario ya que Dinamica no devuelve Tiempos directamente)
% Llamamos a la funci  n de diferenciaci  n *solamente* para extraer el vector de Tiempos acumulado.
[~, ~, Tiempos] = DiferenciarTrayectoriaArticular(TrayArt, params);
fprintf('          Vector de Tiempos extraido para graficas/animacion (Duracion total: %.2f s).\n', Tiempos(end));

% 4.2. EXTRACCION Y GRAFICOS
tau_SCARA = TrayFinalDinamica(:, 10:12);
dq_hist   = TrayFinalDinamica(:, 4:6);
GraficarTorques(TrayFinalDinamica, Tiempos, params); % <-- Asume funci  n GraficarTorques()
fprintf('        Graficos de Din  mica (Torque vs. Tiempo) generados.\n');

% 4.3. ANIMACION
fprintf('   4. Llamando a AnimarTrayectoria.m (Visualizaci  n con factor x%.0f)...\n', params.SpeedUp_Factor);
AnimarTrayectoria(TrayArt, params.L1, params.L2, Tiempos, params.SpeedUp_Factor);

% 4.4. EXPORTAR A CSV (cartesiano y articular)
writematrix(TrayFinal, 'TrayFinal_cart.csv');   % [X Y Z FLAG V]
writematrix(TrayArt, 'TrayFinal_art.csv');      % [d1 th2 th3 FLAG V]
fprintf('        Exportados CSV: TrayFinal_cart.csv y TrayFinal_art.csv\n');

fprintf('\n--- SIMULACION FINALIZADA ---\n');
