function grupos = LeerTrayectoria(filename)
% Leer archivo TXT/CSV, devuelve celda con grupos { [X Y Z CORTAR] }
    if nargin < 1 || isempty(filename)
        [fname, pth] = uigetfile({'*.txt;*.csv','Archivo DXF->TXT (*.txt,*.csv)'}, 'Selecciona archivo');
        if isequal(fname,0), error('No se seleccion   archivo.'); end
        filepath = fullfile(pth, fname);
    else
        filepath = filename;
        if ~exist(filepath,'file'), error('Archivo no encontrado: %s', filepath); end
    end

    data = readmatrix(filepath);  % asumir [X Y Z CORTAR]

    if size(data,2) < 4, error('Archivo inv  lido: debe tener 4 columnas [X Y Z CORTAR].'); end

    X = data(:,1); Y = data(:,2); Z = data(:,3); C = data(:,4);

    % Agrupar por NaN
    idx_nan = find(isnan(X) | isnan(Y) | isnan(Z) | isnan(C));
    idx_nan = [0; idx_nan; numel(X)+1];

    grupos = {};
    for k = 1:length(idx_nan)-1
        ini = idx_nan(k)+1; fin = idx_nan(k+1)-1;
        if fin >= ini
            grupos{end+1} = [X(ini:fin), Y(ini:fin), Z(ini:fin), C(ini:fin)]; %#ok<AGROW>
        end
    end
    fprintf('     Se detectaron %d grupos en el archivo.\n', numel(grupos));
end
