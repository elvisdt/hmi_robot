%% --- Función DibujarScaraCnc lista para animación ---
function handles = DibujarScaraCnc(ax, pos, handles)
    % pos = [O; P; A; B] -> O=base, P=prismático, A=brazo1, B=brazo2/efector
    O = pos(1,:);  % Base
    P = pos(2,:);  % Esbelon prismático (vertical)
    A = pos(3,:);  % Primer brazo
    B = pos(4,:);  % Segundo brazo / efector

    % Verificar si se crean nuevos handles
    createNew = isempty(handles) || ~isfield(handles,'prismatic');

    if createNew
        hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
        xlabel(ax,'X [m]'); ylabel(ax,'Y [m]'); zlabel(ax,'Z [m]');
        view(ax,45,30);

        % Primer eslabón prismático (gris)
        handles.prismatic = plot3(ax, [O(1),P(1)], [O(2),P(2)], [O(3),P(3)],'LineWidth',6,'Color',[0.5 0.5 0.5]);

        % Primer brazo rotacional (azul)
        handles.brazo1 = plot3(ax, [P(1),A(1)], [P(2),A(2)], [P(3),A(3)], 'LineWidth',4,'Color',[0 0 1]);

        % Segundo brazo rotacional (verde)
        handles.brazo2 = plot3(ax, [A(1),B(1)], [A(2),B(2)], [A(3),B(3)], 'LineWidth',4,'Color',[0 0.6 0]);

        % Efector final (rojo)
        handles.tool = plot3(ax, B(1),B(2),B(3), 'o', 'MarkerSize',8, 'MarkerFaceColor','r', 'MarkerEdgeColor','r');

        % Trayectoria del efector final
        handles.tray = plot3(ax, B(1),B(2),B(3), '-', ...
            'Color',[0.1 0.7 1],'LineWidth',1.5);

    else
        % Actualizar posiciones
        set(handles.prismatic,'XData',[O(1),P(1)], 'YData',[O(2),P(2)], 'ZData',[O(3),P(3)]);
        set(handles.brazo1,'XData',[P(1),A(1)], 'YData',[P(2),A(2)], 'ZData',[P(3),A(3)]);
        set(handles.brazo2,'XData',[A(1),B(1)], 'YData',[A(2),B(2)], 'ZData',[A(3),B(3)]);
        set(handles.tool,  'XData',B(1), 'YData',B(2), 'ZData',B(3));

        % Actualizar trayectoria concatenando
        set(handles.tray, 'XData',[get(handles.tray,'XData'), B(1)], ...
                          'YData',[get(handles.tray,'YData'), B(2)], ...
                          'ZData',[get(handles.tray,'ZData'), B(3)]);
    end
end
