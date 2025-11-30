import ezdxf
import numpy as np
import matplotlib.pyplot as plt
from shapely.geometry import LineString, MultiLineString
from shapely.ops import linemerge, unary_union
from scipy.interpolate import splprep, splev
from sklearn.cluster import DBSCAN
import math


from pathlib import Path
from typing import Iterable, List, Sequence

# -------------------------
# Parámetros fijos / supuestos
# -------------------------
ASSUME_DXF_UNITS_MM = True   # asumo que las coordenadas DXF están en mm
PASO_MM = 1.0                # paso de muestreo en XY en mm (fijo, denso)
N_Z_STEPS = 50               # pasos en subida/bajada vertical
TRANSIT_ACCEL_FRAC = 0.2     # fracción para rampa en perfil trapezoidal (20% accel, 60% const, 20% decel)
# -------------------------


# -------------------- 1) Pedir parámetros mínimos (solo 4) --------------------
def pedir_float(msg, default):
    s = input(f"{msg} [{default}]: ").strip()
    return float(s) if s != "" else float(default)

# valdiar unidades a mm
print("UNIDADES: Se asume que el DXF usa mm")
# Z_guardado = pedir_float("Z_guardado [mm]", 200.0)
# Z_corte    = pedir_float("Z_corte [mm]", 150.0)
# V_trans    = pedir_float("Velocidad_transicion [mm/s]", 50.0)   # para saltos/subidas
# V_corte    = pedir_float("Velocidad_corte [mm/s]", 20.0)       # para corte (lineal sobre material)


Z_guardado =  200.0
Z_corte    =  150.0
V_trans    =  50.0   # para saltos/subidas
V_corte    =  20.0       # para corte (lineal sobre material)

# convertir velocidades to mm (we keep mm units internally)
paso = PASO_MM
Zg = Z_guardado
Zc = Z_corte
n_z = int(N_Z_STEPS)




# -------------------- 2) Cargar DXF --------------------
dxf_file = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\logo7_especial.dxf")
print(f" Archivo: {dxf_file}")

doc = ezdxf.readfile(dxf_file)
msp = doc.modelspace()



# -------------------- 3) Leer entidades (tu lector robusto) --------------------
geoms = []
colores = []

def obtener_color_real(ent):
    """Devuelve color ACI (int) o truecolor (tuple) si está presente, o color de la capa."""
    try:
        # true color:
        if hasattr(ent.dxf, "true_color") and ent.dxf.get("true_color", None):
            try:
                rgb = ent.rgb
                if rgb is not None:
                    return tuple(rgb)  # (r,g,b)
            except Exception:
                pass
        color_index = int(getattr(ent.dxf, "color", 7))
        if color_index <= 0 or color_index == 256:
            # usar color de la capa
            layer = ent.dxf.layer
            layer_color_index = int(doc.layers.get(layer).color)
            return layer_color_index
        return color_index
    except Exception:
        return 7

def procesar_entidad(e):
    dtype = e.dxftype()
    color = obtener_color_real(e)
    puntos = []
    try:
        if dtype == "LINE":
            s, e2 = e.dxf.start, e.dxf.end
            puntos = [[s.x, s.y], [e2.x, e2.y]]
        elif dtype == "LWPOLYLINE":
            pts = np.array(e.get_points())[:, :2]
            puntos = pts
        elif dtype == "POLYLINE":
            pts = [v.dxf.location[:2] for v in e.vertices]
            puntos = np.array(puntos) if len(pts)==0 else np.array(pts)
        elif dtype == "CIRCLE":
            c, r = e.dxf.center, e.dxf.radius
            t = np.linspace(0, 2*np.pi, 200)
            puntos = np.column_stack([c.x + r*np.cos(t), c.y + r*np.sin(t)])
        elif dtype == "ARC":
            c, r = e.dxf.center, e.dxf.radius
            a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
            t = np.linspace(a1, a2, 120)
            puntos = np.column_stack([c.x + r*np.cos(t), c.y + r*np.sin(t)])
        elif dtype == "SPLINE":
            fit = np.array(e.fit_points)
            if len(fit) >= 2:
                tck, _ = splprep([fit[:,0], fit[:,1]], s=0)
                u = np.linspace(0, 1, 200)
                x, y = splev(u, tck)
                puntos = np.column_stack([x, y])
            else:
                ctrl = np.array(e.control_points)
                if len(ctrl) >= 2:
                    tck, _ = splprep([ctrl[:,0], ctrl[:,1]], s=0)
                    u = np.linspace(0, 1, 200)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
        if len(puntos) > 1:
            geoms.append(LineString(puntos))
            colores.append(color)
    except Exception as ex:
        print(f"No se pudo procesar {dtype}: {ex}")

for ent in msp:
    procesar_entidad(ent)

if not geoms:
    raise ValueError("No se detectaron entidades válidas en el DXF.")





# -------------------- 4) Clasificar por color: corte / no corte --------------------
def es_amarillo(c):
    if isinstance(c, (tuple, list)):
        r,g,b = c
        return (r >= 200 and g >= 200 and b <= 120)
    else:
        try:
            return int(c) == 2
        except:
            return False

geoms_corte_raw = []
geoms_nocorte_raw = []
for g,c in zip(geoms, colores):
    if es_amarillo(c):
        geoms_nocorte_raw.append(g)
    else:
        geoms_corte_raw.append(g)

print(f"Total entidades: {len(geoms)} | Corte: {len(geoms_corte_raw)} | No corte (amarillo): {len(geoms_nocorte_raw)}")


# -------------------- 5) Sanitizar / unir geoms de corte (linemerge) --------------------
if len(geoms_corte_raw) == 0:
    raise ValueError("No hay entidades de corte (todas amarillas?)")

union = unary_union(geoms_corte_raw)
merged = linemerge(union)
if isinstance(merged, LineString):
    merged = [merged]
elif isinstance(merged, MultiLineString):
    merged = list(merged.geoms)

# merged ahora contiene trayectorias continuas (cada elemento = un 'grupo' candidato)
groups = merged  # lista de LineString
print(f"Grupos detectados (merged): {len(groups)}")



# -------------------- 6) Resample helper --------------------
def resample_linestring(ls: LineString, paso_mm=1.0):
    pts = np.array(ls.coords)
    segs = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    if segs.sum() == 0:
        return pts
    s = np.concatenate(([0.0], np.cumsum(segs)))
    s_new = np.arange(0, s[-1] + 1e-9, paso_mm)
    xs = np.interp(s_new, s, pts[:,0])
    ys = np.interp(s_new, s, pts[:,1])
    return np.vstack([xs, ys]).T

# -------------------- 7) Orden óptimo de grupos (nearest neighbor sobre centroides) --------------------
centers = np.array([np.array(g.centroid.coords[0]) for g in groups])
def nearest_neighbor_order(centers):
    n = len(centers)
    if n == 0: return []
    remaining = set(range(n))
    # init at centroid nearest to origin (0,0)
    start = int(np.argmin([np.linalg.norm(c - np.array([0.0,0.0])) for c in centers]))
    order = [start]; remaining.remove(start)
    cur = start
    while remaining:
        nxt = min(remaining, key=lambda j: np.linalg.norm(centers[cur]-centers[j]))
        order.append(nxt)
        remaining.remove(nxt)
        cur = nxt
    return order

order = nearest_neighbor_order(centers)
print("Orden de recorrido (indices):", order)




# -------------------- 8) Perfiles de velocidad --------------------
def perfil_trapezoidal(dist, v_max, frac_acc=TRANSIT_ACCEL_FRAC, steps=None):
    # crear vector de velocidades a lo largo de la distancia (length = steps)
    if steps is None or steps < 2:
        steps = max(2, int(np.ceil(dist / paso)))
    t = np.linspace(0, 1, steps)
    acc_t = frac_acc
    dec_t = 1 - frac_acc
    vmax = v_max
    def piece(ti):
        if ti < acc_t:
            return vmax * (ti / acc_t)
        elif ti > dec_t:
            return vmax * (1 - (ti - dec_t)/(1 - dec_t))
        else:
            return vmax
    vec = np.array([piece(ti) for ti in t])
    return vec

def perfil_s_curve(steps, v_max):
    t = np.linspace(0, 1, steps)
    # suavizado tipo sin (0->1): v = v_max * (0.5 - 0.5 cos(pi t))
    v = v_max * (0.5 - 0.5 * np.cos(np.pi * t))
    return v

# -------------------- 9) Construir trayectoria 3D final (solo grupos de corte) --------------------
tray_pts = []   # list of [x,y,z,v]
visual_3d = []  # for plotting

prev_guard_xy = None

for idx in order:
    group = groups[idx]
    # sample XY of this group
    pts_xy = resample_linestring(group, paso_mm=PASO_MM)
    if pts_xy.shape[0] < 2:
        continue

    # Decide orientation minimizing transit distance from prev_guard_xy
    start_xy = pts_xy[0]; end_xy = pts_xy[-1]
    if prev_guard_xy is None:
        # choose orientation where start closer to origin
        if np.linalg.norm(end_xy - np.array([0.0,0.0])) < np.linalg.norm(start_xy - np.array([0.0,0.0])):
            pts_xy = pts_xy[::-1]
            start_xy = pts_xy[0]; end_xy = pts_xy[-1]
    else:
        d_start = np.linalg.norm(prev_guard_xy - start_xy)
        d_end   = np.linalg.norm(prev_guard_xy - end_xy)
        if d_end < d_start:
            pts_xy = pts_xy[::-1]
            start_xy = pts_xy[0]; end_xy = pts_xy[-1]

    # 1) Transit at Z_guardado from prev_guard_xy to start_xy (if prev exists)
    if prev_guard_xy is None:
        # initial move: jump to first start at Zg (no long transit)
        transit_xy = np.array([start_xy])
    else:
        dist_transit = np.linalg.norm(start_xy - prev_guard_xy)
        n_steps_trans = max(2, int(np.ceil(dist_transit / PASO_MM)))
        xs = np.linspace(prev_guard_xy[0], start_xy[0], n_steps_trans)
        ys = np.linspace(prev_guard_xy[1], start_xy[1], n_steps_trans)
        transit_xy = np.column_stack([xs, ys])

    # transit points at Zg with trapezoidal profile using V_trans
    n_t = transit_xy.shape[0]
    v_trans_profile = perfil_trapezoidal(dist=np.sum(np.linalg.norm(np.diff(transit_xy, axis=0), axis=1)),
                                         v_max=V_trans, steps=n_t)
    for p, vv in zip(transit_xy, v_trans_profile):
        tray_pts.append([p[0], p[1], Zg, vv])
        visual_3d.append([p[0], p[1], Zg])

    # 2) Descent vertical to Zc (n_z steps) at start_xy (use V_trans)
    zs_desc = np.linspace(Zg, Zc, n_z)
    for z in zs_desc:
        tray_pts.append([start_xy[0], start_xy[1], z, V_trans])
        visual_3d.append([start_xy[0], start_xy[1], z])

    # 3) Cut along pts_xy at Zc with S-curve profile and V_corte
    n_cut = pts_xy.shape[0]
    v_cut_profile = perfil_s_curve(n_cut, V_corte)
    for (p, vv) in zip(pts_xy, v_cut_profile):
        tray_pts.append([p[0], p[1], Zc, float(vv)])
        visual_3d.append([p[0], p[1], Zc])

    # 4) Ascent vertical to Zg (n_z steps) at end point
    zs_asc = np.linspace(Zc, Zg, n_z)
    last_xy = pts_xy[-1]
    for z in zs_asc:
        tray_pts.append([last_xy[0], last_xy[1], z, V_trans])
        visual_3d.append([last_xy[0], last_xy[1], z])

    # mark separator by appending a NaN sentinel row (we'll write NaN separators when exporting)
    tray_pts.append([np.nan, np.nan, np.nan, np.nan])

    # update prev_guard_xy
    prev_guard_xy = np.array([last_xy[0], last_xy[1]])

# remove trailing NaN if present
if len(tray_pts) and all([math.isnan(x) for x in tray_pts[-1]]):
    pass  # keep final NaN separator (okay)

tray_arr = np.array(tray_pts, dtype=float)
print(f"Total puntos en trayectoria (incl. NaN sep): {tray_arr.shape[0]}")



# -------------------- 10) Exportar Trayectoria_final_3D.txt --------------------
outname = "Trayectoria_final_3D.txt"
with open(outname, "w") as f:
    f.write("X Y Z V\n")
    for row in tray_arr:
        if np.isnan(row).any():
            f.write("NaN NaN NaN NaN\n")
        else:
            f.write(f"{row[0]:.6f} {row[1]:.6f} {row[2]:.6f} {row[3]:.6f}\n")


print(f"Exportado: {outname}")



# -------------------- 11) Visualizaciones --------------------
# 2D plot (verde = corte, amarillo = no corte)
plt.figure(figsize=(8,8))
for g in geoms_corte_raw:
    x,y = g.xy
    plt.plot(x,y,color="#00ff00", linewidth=1.2)
for g in geoms_nocorte_raw:
    x,y = g.xy
    plt.plot(x,y,color="yellow", linewidth=2.2, linestyle="--")
plt.axis("equal"); plt.title("2D: Verde = corte | Amarillo = no corte"); plt.grid(True)
plt.show()



# 3D plot of final trajectory
from mpl_toolkits.mplot3d import Axes3D
fig = plt.figure(figsize=(10,6))
ax = fig.add_subplot(111, projection='3d')
tp = np.array(visual_3d)
if tp.size:
    ax.plot(tp[:,0], tp[:,1], tp[:,2], linewidth=0.8)
ax.set_xlabel("X (mm)"); ax.set_ylabel("Y (mm)"); ax.set_zlabel("Z (mm)")
ax.set_title("Trayectoria 3D generada (mm)")
plt.show()
