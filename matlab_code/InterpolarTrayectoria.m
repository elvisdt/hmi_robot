function TrayInt = InterpolarTrayectoria(TrayBruta, paso, Z_cut)
% Interpola la trayectoria, forzando Z a Z_cut para el trabajo (FLAG=1)
% y EXCLUYENDO completamente los grupos donde todos los puntos son FLAG=0.
%
% FLAG KEY: 1=Corte (a Z_cut), 2=Reposo (a Z_home), 3=Traslado Seguro (a Z_home).

    if nargin < 2, paso = 1; end
    if nargin < 3, error('Z_cut debe ser proporcionado.'); end
    TrayInt = [];
    
    % --- 1. PREPARACIÓN DE GRUPOS VÁLIDOS (Filtrado de FLAG=0) ---
    GruposValidos = {};
    num_grupos_inicial = 0;
    num_grupos_filtrados = 0;
    
    for k = 1:length(TrayBruta)
        g = TrayBruta{k};
        num_grupos_inicial = num_grupos_inicial + 1;
        
        if isempty(g) || all(all(isnan(g))), continue; end
        
        Flags_del_grupo = g(:,4);
        
        % Filtrar: Solo incluir si contiene CUALQUIER FLAG diferente de 0.
        if ~all(Flags_del_grupo == 0)
            GruposValidos{end+1} = g;
            num_grupos_filtrados = num_grupos_filtrados + 1;
        end
    end
    
    % --- 2. INTERPOLAR CADA GRUPO RESTANTE (FLAG=1, 2, 3) ---
    for k = 1:length(GruposValidos)
        g = GruposValidos{k};
        
        X = g(:,1); 
        Y = g(:,2);
        Cortar_Flag = g(:,4); 
        Flag_bloque = Cortar_Flag(1);
        
        % === CORRECCIÓN CLAVE DE Z ===
        % Si es CORTE (1), forzamos Z = Z_cut.
        if Flag_bloque == 1
            Z = Z_cut * ones(size(X));
        else
            % Si es Reposo (2) o Traslado Seguro (3), mantenemos la Z original (Z_home).
            Z = g(:,3); 
        end
        % ==============================
        
        % Limpieza de NaNs y lógica de Z constante
        nan_rows = isnan(X) | isnan(Y);
        X(nan_rows) = []; Y(nan_rows) = []; Z(nan_rows) = []; Cortar_Flag(nan_rows) = [];
        
        Z_initial = Z(1);
        Z = Z_initial * ones(size(Z));
        
        % --- Cálculo de largo acumulado y Interpolación ---
        dist = [0; cumsum(sqrt(diff(X).^2 + diff(Y).^2))];
        L = dist(end);
        
        if L < paso || numel(X) < 2
            X_int = X; Y_int = Y; Z_int = Z; Cortar_int = Cortar_Flag;
        else
            s_int = 0:paso:L;
            X_int = interp1(dist, X, s_int, 'linear')';
            Y_int = interp1(dist, Y, s_int, 'linear')';
            Z_int = Z_initial * ones(numel(X_int), 1); 
            Cortar_int = repmat(Flag_bloque, numel(X_int), 1);
        end
        
        % --- Acumular resultados y Separador NaN ---
        TrayInt = [TrayInt; [X_int(:) Y_int(:) Z_int(:) Cortar_int(:)]];
        if k < length(GruposValidos)
            TrayInt = [TrayInt; NaN(1,4)];
        end
    end
    fprintf('✨ Se filtraron %d grupos con FLAG=0. Interpolados %d grupos finales (Corte/Guardado).\n', num_grupos_inicial - num_grupos_filtrados, num_grupos_filtrados);
end