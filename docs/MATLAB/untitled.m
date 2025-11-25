%% --- Animación SCARA-CNC usando Cinemática Inversa y Directa ---
clc; clear; close all;

%% --- Parámetros del robot ---
L1 = 0.3; % metros
L2 = 0.2; % metros

%% --- Leer archivo de trayectoria ---
[archivo, ruta] = uigetfile('*.txt','Selecciona el archivo de trayectoria');
if isequal(archivo,0), error('No se seleccionó archivo'); end
filename = fullfile(ruta, archivo);

% Leer y procesar trayectoria
GruposBrutos = LeerTrayectoria(filename);
paso   = 1;     % mm
Z_home = 0.2;   % m
Z_cut  = 0.16;  % m
TrayInt = InterpolarTrayectoria(GruposBrutos, paso);
Speed_cut = 0.08;     % m/s
Speed_traslado = 0.12;% m/s
TrayFinal = PlanificarTrayectoria(TrayInt, Z_home*1000, Z_cut*1000, paso, Speed_cut*1000*60, Speed_traslado*1000*60);

% Convertir TrayFinal de mm→m
TrayFinal(:,1:3) = TrayFinal(:,1:3)/1000;

%% --- Cinemática Inversa ---
[th1_all, th2_all, d1_all, info] = CinematicaInversa(TrayFinal(:,1:3), L1, L2, 'Elbow','down');

%% --- Configurar animación ---
figure;
ax = gca; hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
view(45,30);
title('Animación SCARA-CNC');

% límites
Ltot = L1+L2;
xlim([-1.5*Ltot, 1.5*Ltot]);
ylim([-1.5*Ltot, 1.5*Ltot]);
zlim([0, 1.2*Z_home]);

% handles
handles = struct();

%% --- Animación paso a paso ---
skip = 3; % saltar puntos para acelerar
dt_min = 0.002; dt_max = 0.05;

tipo_actual = TrayFinal(1,4); % 0=traslado, 1=corte
col = 'c'; if tipo_actual==1, col='y'; end
segmento = plot3(NaN,NaN,NaN,'Color',col,'LineWidth',2);
Xs=[]; Ys=[]; Zs=[];

punto = plot3(TrayFinal(1,1), TrayFinal(1,2), TrayFinal(1,3), ...
    'ro','MarkerFaceColor','r','MarkerSize',6);

for i = 2:skip:length(TrayFinal)
    if any(isnan(TrayFinal(i,:))), continue; end

    % --- Obtener posición del robot usando cinemática directa ---
    th2 = th2_all(i); th3 = th1_all(i); d1 = d1_all(i);
    pos_joints = CinematicaDirecta(th2, th3, L1, L2, d1);

    % --- Dibujar robot ---
    handles = DibujarScaraCnc(ax, pos_joints, handles, Z_cut);

    % --- Actualizar segmento de trayectoria ---
    p2 = TrayFinal(i,1:3);
    if TrayFinal(i,4) ~= tipo_actual
        tipo_actual = TrayFinal(i,4);
        col = 'c'; if tipo_actual==1, col='y'; end
        Xs=[]; Ys=[]; Zs=[];
        segmento = plot3(NaN,NaN,NaN,'Color',col,'LineWidth',2);
    end
    Xs(end+1) = p2(1); Ys(end+1) = p2(2); Zs(end+1) = p2(3);
    set(segmento,'XData',Xs,'YData',Ys,'ZData',Zs);

    % actualizar punto rojo
    set(punto,'XData',p2(1),'YData',p2(2),'ZData',p2(3));

    % calcular tiempo de pausa según velocidad
    dist = norm(p2 - TrayFinal(i-1,1:3));
    vel  = max(TrayFinal(i,5),1e-6);
    dt = max(dt_min, min(dist/vel, dt_max));

    drawnow limitrate;
    pause(dt);
end

disp('✅ Animación SCARA-CNC completa.');
