# Interfaz de Control del Robot SCARA

Aplicación Qt/QML (PySide6) para importar trayectorias 2D (DXF/CSV), visualizarlas en plano 2D y escena 3D, y reproducirlas en un robot SCARA simulado. Orientada a uso académico (sustentación de tesis) y demostración de flujo CAD → simulación → reproducción articular.

## Requisitos

- Python 3.10+
- PySide6 (instalable con `requirements.txt`)

```bash
python -m venv .venv
.\.venv\Scripts\activate   # Windows
pip install -r requirements.txt
```

## Ejecución

```bash
python main.py
```

La ventana principal (`qml/Main.qml`) integra:
- Panel de control (importación DXF/CSV, procesamiento, controles de robot).
- Visor 2D (`Viewer2D`): grilla/ejes, ajuste automático al DXF/CSV, overlay del brazo 2D sincronizado con ángulos R1/R2.
- Visor 3D (`RobotView`): modelo SCARA, reproducción de trayectoria articular y barra de progreso.

## Flujo de uso

1. **Importar CAD**: seleccionar un DXF o CSV/TXT con puntos; el plano 2D se ajusta y muestra grilla/ejes.  
2. **Procesamiento**: previsualizar/exportar (G-code) según tu backend.  
3. **Robot**: cargar trayectoria articular CSV, controlar Home/Reset/Play/Stop y velocidad; el progreso se refleja en `RobotView`.  
4. **Sincronía 2D/3D**: el overlay del brazo 2D sigue los ángulos R1/R2; el 3D reproduce la misma trayectoria.

## Estructura

- `main.py`: arranque de la aplicación.
- `qml/Main.qml`: layout principal y conexiones con backend.
- `qml/Viewer2D.qml` + `qml/component/View2DCanvas.qml`: visor 2D con auto-fit, grilla, ejes y brazo 2D.
- `qml/RobotView.qml` + `qml/Robot.qml`: escena 3D y reproducción articular.
- `core/backend.py`: carga DXF/CSV y entrega puntos al visor 2D.
- `docs/trayectorias/`, `docs/dxf_files/`: ejemplos de trayectorias y DXF.

## Parámetros clave

- Longitudes del brazo en `qml/RobotView.qml`: `l1mm`, `l2mm` (se reflejan en 2D y 3D).
- Paletas claro/oscuro en `qml/component/Theme.qml` (se aplican a visores y controles).

## Publicación

Incluye este README, el `requirements.txt` y los ejemplos en `docs/`. Ideal para repositorios Git indexados en la documentación de la tesis.
