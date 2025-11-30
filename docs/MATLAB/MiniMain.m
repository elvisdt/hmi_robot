%% --- MiniMain Final Optimizada SCARA-CNC P-R-R ---
clc; clear; close all;

%% --- Par  metros del robot (Ejemplo) ---
L1 = 0.6;   % mm
L2 = 0.65;  % mm

%% --- Par  metros de trayectoria (Ejemplo) ---
Z_home = 200;   % altura de guardado [mm]
Z_cut  = 150;  % altura de corte [mm]
paso   = 1;     % resoluci  n de interpolaci  n [mm] <--- AHORA EN MM
ratio  = 0.3;
Speed_traslado = 12000; % Velocidad de traslado [mm/min] <--- AHORA EN MM/MIN
Speed_cut      = ratio*Speed_traslado;

%% --- Leer archivo de trayectoria ---
[archivo, ruta] = uigetfile('*.txt','Selecciona archivo de trayectoria');
if isequal(archivo,0), error('No se seleccion   archivo'); end
filename = fullfile(ruta, archivo);

%% --- Leer grupos e interpolar ---
GruposBrutos = LeerTrayectoria(filename);           
TrayInt      = InterpolarTrayectoria(GruposBrutos, paso);

%% --- Planificar trayectoria completa ---
TrayFinal = PlanificarTrayectoria(TrayInt, Z_home, Z_cut, paso, Speed_cut, Speed_traslado);

%% --- Cinem  tica inversa ---
TrayArt = CinematicaInversa(TrayFinal(:,1:5), L1, L2); % Nx5 [th1 th2 d1 flag v]

%% --- Cinem  tica directa vectorizada ---
AnimarTrayectoria(TrayArt, L1, L2);

% %% --- Inicializar figura ---
% figure('Color',[1 1 1]);
% ax = gca; hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
% xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
% title('Animaci  n SCARA-P-R-R con Trayectoria');
% view(45,30);
% 
% % Limites del eje
% Ltot = L1 + L2;
% padding = 0.2 * Ltot;
% xlim(ax,[-Ltot-padding, Ltot+padding]);
% ylim(ax,[-Ltot-padding, Ltot+padding]);
% zlim(ax,[0, max(1.2*Z_home, Z_cut+0.1)]);
% 
% % Dibujar trayectoria de referencia (l  nea fina)
% plot3(ax, TrayFinal(:,1), TrayFinal(:,2), TrayFinal(:,3), 'k:', 'LineWidth', 0.6);
% 
% % Inicializar punto efector final
% punto = plot3(ax, TrayFinal(1,1), TrayFinal(1,2), TrayFinal(1,3), ...
%               'ro','MarkerFaceColor','r','MarkerSize',6);
% 
% % Inicializar primer segmento coloreado
% tipo_actual = TrayFinal(1,4); % 0=traslado, 1=corte
% col = 'c'; if tipo_actual==1, col='y'; end
% segmento = plot3(ax, NaN, NaN, NaN,'Color',col,'LineWidth',2);
% Xs=[]; Ys=[]; Zs=[];
% 
% % Handles del robot
% handles = struct();

% %% --- Animaci  n ---
% dt_min = 0.002; dt_max = 0.05;
% N = size(TrayFinal,1);
% 
% for i = 1:N
%     if any(isnan(TrayFinal(i,:))), continue; end
% 
%     % Posiciones de la cinem  tica directa
%     pos_joints = [O_all(i,:); P_all(i,:); A_all(i,:); B_all(i,:)];
% 
%     % Dibujar/actualizar robot
%     handles = DibujarScaraCnc(ax, pos_joints, handles);
% 
%     % Actualizar segmento coloreado
%     p2 = TrayFinal(i,1:3);
%     if TrayFinal(i,4) ~= tipo_actual
%         tipo_actual = TrayFinal(i,4);
%         if tipo_actual == 1, col = 'y'; else col = 'c'; end
%         Xs=[]; Ys=[]; Zs=[];
%         if ishandle(segmento), delete(segmento); end
%         segmento = plot3(ax, NaN,NaN,NaN,'Color',col,'LineWidth',2);
%     end
%     Xs(end+1) = p2(1); Ys(end+1) = p2(2); Zs(end+1) = p2(3);
%     set(segmento,'XData',Xs,'YData',Ys,'ZData',Zs);
% 
%     % Actualizar punto efector
%     set(punto,'XData',p2(1),'YData',p2(2),'ZData',p2(3));
% 
%     % Pausa seg  n velocidad
%     if i>1
%         dist = norm(p2 - TrayFinal(i-1,1:3));
%         vel  = max(TrayFinal(i,5),1e-6);
%         dt   = dist/vel;
%         dt   = max(dt_min, min(dt, dt_max));
%         pause(dt);
%     end
% 
%     drawnow limitrate;
% end
% 
% disp('    Animaci  n SCARA-P-R-R completa con robot y trayectoria.');
