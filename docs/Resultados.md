# 4. Resultados y Evaluacion de Impacto

Guia para documentar los resultados del proyecto SCARA (cinematica, dinamica y validacion). Completa cada apartado con tus datos medidos/simulados; deja las tablas como base.

## 4.1 Analisis del Desempeno (cinematica, dinamica, precision)

- **Contexto de prueba**: robot SCARA P-R-R, L1/L2, masas, limites `Qdot_max`, `Qddot_max`, `A_max_cart`, velocidades de corte/traslado, paso de interpolacion y `Fs`.

- **Cinematica (directa/inversa)**  
  - Error cartesiano: RMSE y maximo (XY y Z) por trayectoria.  
  - Figuras: trayectorias 3D (corte vs traslado), mapa de calor de error XY y Z.

- **Dinamica**  
  - Perfiles `q`, `qdot`, `qddot` (suavidad, sin picos).  
  - Torques/Fuerzas: pico y RMS por articulacion; margen a limites de actuadores.  
  - Figuras: `tau` vs tiempo, `tau` vs `qdot` (envolvente), `qdot` y `qddot` vs tiempo.

- **Precision / repetibilidad**  
  - Desviacion estandar de la punta en puntos clave; error en vertices de figuras.  
  - Tabla: error medio y maximo en XY/Z por prueba.

### Tabla ejemplo - Error cartesiano
| Trayectoria | RMSE XY [mm] | Max XY [mm] | RMSE Z [mm] | Max Z [mm] |
|-------------|--------------|-------------|-------------|------------|
| Figura A    |              |             |             |            |
| Figura B    |              |             |             |            |

### Tabla ejemplo - Torques/Fuerzas
| Articulacion | Pico [N/Nm] | RMS [N/Nm] | Limite [N/Nm] | Margen [%] |
|--------------|-------------|------------|---------------|------------|
| d1           |             |            |               |            |
| th2          |             |            |               |            |
| th3          |             |            |               |            |

## 4.2 Comparacion del Proceso (actual vs propuesta)

- **Metodologia**: mismas condiciones (geometria, velocidades, carga).  
- **Metricas clave**: tiempo de ciclo (total, corte, traslados), suavidad (picos de `qdot`/`qddot`), torques pico/RMS y margen, precision final.  
- **Figuras**: barras de tiempos de ciclo; superposicion de trayectorias 3D; envolventes `tau` vs `qdot`; perfiles de velocidad.
- **Validaciones**: simulaciones (`AnimarTrayectoria`, `PlanificarTrayectoria`), chequeo de limites (sin saturar), jacobiano para fuerzas externas si aplica.
- **Impacto**: reduccion de tiempo de ciclo, menor exigencia de actuadores, mejora de precision; riesgos/pedientes (tuning de parametros, validacion hardware).

### Tabla resumen - Actual vs Propuesta
| Metrica                 | Actual | Propuesta | Mejora [%] |
|-------------------------|--------|-----------|------------|
| Tiempo total de ciclo   |        |           |            |
| Tiempo en corte         |        |           |            |
| Tiempo en traslados     |        |           |            |
| Error max XY [mm]       |        |           |            |
| Error max Z [mm]        |        |           |            |
| Torque pico th2 [Nm]    |        |           |            |
| Torque pico th3 [Nm]    |        |           |            |

## Apoyo desde el codigo (rutas utiles)
- Cinematica: `docs/MATLAB/CinematicaDirecta.m`, `docs/MATLAB/CinematicaInversa.m`
- Trayectoria y perfiles: `docs/MATLAB/PlanificarTrayectoria.m`, `docs/MATLAB/DiferenciarTrayectoriaArticular.m`, `docs/MATLAB/AnimarTrayectoria.m`
- Dinamica/torques: `docs/MATLAB/Dinamica.m`, `docs/MATLAB/ModeloDin.m`, `docs/MATLAB/Torques.m`, `docs/MATLAB/GraficarTorques.m`

## Checklist de evidencias a incluir
- Figuras 3D de trayectorias (corte vs traslado) y error cartesiano.
- Graficos `tau` vs tiempo y `tau` vs `qdot` con limites marcados.
- Perfiles de `qdot` y `qddot` mostrando suavidad y ausencia de picos.
- Tablas de error y comparacion actual vs propuesta.
- Nota breve de validacion (simulacion y, si aplica, prueba hardware).
