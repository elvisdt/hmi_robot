
import ezdxf
import numpy as np
import matplotlib.pyplot as plt
from shapely.geometry import LineString, MultiLineString, Polygon, LinearRing, Point
from shapely.ops import linemerge, unary_union, polygonize
from scipy.interpolate import splprep, splev
from sklearn.cluster import DBSCAN
import math
import io
import sys

# -------------------------
# Parámetros que puedes ajustar
# -------------------------
TOL_TOPO = 0.05          # tolerancia para unir extremos (mm)
EXPORT_IN_METERS = True  # True -> divide por 1000 al exportar
INTERPOLATION_POINTS = 200 # puntos para CIRCLE/ARC/SPLINE
MIN_RING_LEN = 1e-6      # tolerancia para descartar anillos degenerados
SIMPLIFY_TOLERANCE = 0.01 # <--- NUEVO: Tolerancia para simplificar polígonos (en mm)
# -------------------------------------------------------------
# 1️⃣ SUBIR ARCHIVO DXF (CÓDIGO CORREGIDO)
# -------------------------------------------------------------
print("📂 Sube el archivo DXF que deseas procesar:")

dxf_file = r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\corte_especial.dxf"
# -------------------------------------------------------------
# 2️⃣ LECTOR DXF UNIVERSAL (XY + color + layer)
# -------------------------------------------------------------
doc = ezdxf.readfile(dxf_file)
msp = doc.modelspace()
geoms = []

def procesar_entidad(e):
    dtype = e.dxftype()
    color = None
    layer = None
    try:
        color = int(e.dxf.color) if hasattr(e.dxf, "color") else None
    except Exception:
        color = None
    try:
        layer = str(e.dxf.layer) if hasattr(e.dxf, "layer") else ""
    except Exception:
        layer = ""
    puntos = None
    try:
        if dtype == "LINE":
            start, end = e.dxf.start, e.dxf.end
            puntos = np.array([[start.x, start.y], [end.x, end.y]])
        elif dtype == "LWPOLYLINE":
            pts = np.array(e.get_points())[:, :2]
            puntos = pts
        elif dtype == "POLYLINE":
            pts = [v.dxf.location[:2] for v in e.vertices]
            puntos = np.array(pts)
        elif dtype == "CIRCLE":
            c, r = e.dxf.center, e.dxf.radius
            t = np.linspace(0, 2*np.pi, INTERPOLATION_POINTS)
            puntos = np.column_stack([c.x + r*np.cos(t), c.y + r*np.sin(t)])
        elif dtype == "ARC":
            c, r = e.dxf.center, e.dxf.radius
            a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
            # Manejar arcs que pasan por 0 grados
            if a2 < a1:
                a2 += 2*np.pi
            t = np.linspace(a1, a2, max(10, INTERPOLATION_POINTS//2))
            puntos = np.column_stack([c.x + r*np.cos(t), c.y + r*np.sin(t)])
        elif dtype == "SPLINE":
            # Intentar fit points luego control points
            try:
                fit = np.array(e.fit_points)
            except Exception:
                fit = np.array([])
            if fit is not None and len(fit) >= 2:
                tck, _ = splprep([fit[:,0], fit[:,1]], s=0)
                u = np.linspace(0, 1, INTERPOLATION_POINTS)
                x, y = splev(u, tck)
                puntos = np.column_stack([x, y])
            else:
                try:
                    ctrl = np.array(e.control_points)
                except Exception:
                    ctrl = np.array([])
                if len(ctrl) >= 2:
                    tck, _ = splprep([ctrl[:,0], ctrl[:,1]], s=0)
                    u = np.linspace(0, 1, INTERPOLATION_POINTS)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
        # Si obtuvimos puntos los convertimos a LineString
        if puntos is not None and len(puntos) > 1:
            # eliminar duplicados consecutivos
            pts = [tuple(p) for p in puntos]
            pts_clean = [pts[0]]
            for p in pts[1:]:
                if p != pts_clean[-1]:
                    pts_clean.append(p)
            if len(pts_clean) > 1:
                geoms.append({"geom": LineString(pts_clean), "color": color, "layer": layer, "type": dtype})
    except Exception as ex:
        print(f"⚠️ No se pudo procesar {dtype}: {ex}")

for e in msp:
    procesar_entidad(e)

if not geoms:
    raise ValueError("⚠️ No se detectaron entidades válidas en el DXF.")

# -------------------------------------------------------------
# 3️⃣ SEPARAR POR COLOR (CORTAR / NO CORTAR)
# -------------------------------------------------------------
def clasificar_color(color, layer):
    # regla simple: color 2 o capas con "NO" => NO_CORTAR (ajusta a tu convención)
    if color is not None and int(color) == 2:
        return "NO_CORTAR"
    if isinstance(layer, str) and "NO" in layer.upper():
        return "NO_CORTAR"
    return "CORTAR"

geoms_cortar = [g["geom"] for g in geoms if clasificar_color(g["color"], g["layer"]) == "CORTAR"]
geoms_nocortar = [g["geom"] for g in geoms if clasificar_color(g["color"], g["layer"]) == "NO_CORTAR"]

print(f"✂️ Figuras a cortar (raw): {len(geoms_cortar)}")
print(f"🚫 Figuras NO cortar (raw): {len(geoms_nocortar)}")

# -------------------------------------------------------------
# 4️⃣ UNIR TOPOLOGICAMENTE (agrupar segmentos que conectan)
# -------------------------------------------------------------
def unir_topologicamente(geoms, tolerancia=TOL_TOPO):
    if not geoms:
        return []
    endpoints = []
    for gi, g in enumerate(geoms):
        coords = list(g.coords)
        endpoints.append(coords[0])
        endpoints.append(coords[-1])
    endpoints = np.array(endpoints)
    if len(endpoints) == 0:
        return []
    labels = DBSCAN(eps=tolerancia, min_samples=1).fit_predict(endpoints)
    n_clusters = labels.max() + 1
    centroids = np.zeros((n_clusters, 2))
    for k in range(n_clusters):
        pts = endpoints[labels == k]
        centroids[k] = pts.mean(axis=0)
    geoms_sanitized = []
    for gi, g in enumerate(geoms):
        coords = list(g.coords)
        label_start = labels[2*gi]
        label_end = labels[2*gi + 1]
        new_coords = coords.copy()
        new_coords[0] = tuple(centroids[label_start])
        new_coords[-1] = tuple(centroids[label_end])
        # evitar duplicados extremos
        if len(new_coords) >= 2 and new_coords[0] == new_coords[-1]:
            ls = LineString(new_coords)
        else:
            ls = LineString(new_coords)
        geoms_sanitized.append(ls)
    union = unary_union(geoms_sanitized)
    merged = linemerge(union)
    merged_list = []
    if isinstance(merged, LineString):
        merged_list = [merged]
    elif isinstance(merged, MultiLineString):
        merged_list = list(merged.geoms)
    else:
        # fallback: if union is Multi* or GeometryCollection try to extract lines
        try:
            for g in merged:
                if isinstance(g, LineString):
                    merged_list.append(g)
        except Exception:
            pass
    return merged_list

merged_cortar = unir_topologicamente(geoms_cortar, tolerancia=TOL_TOPO)
merged_nocortar = unir_topologicamente(geoms_nocortar, tolerancia=TOL_TOPO)

print(f"✅ Trayectorias parcialmente unidas: cortar = {len(merged_cortar)}, no cortar = {len(merged_nocortar)}")

# -------------------------------------------------------------
# 5️⃣ EXTRACCIÓN DE ANILLOS (RINGS) y LÍNEAS ABIERTAS
#     Además intentamos polygonize para captar polígonos formados por múltiples segmentos
# -------------------------------------------------------------
def extract_rings_and_openlines(merged_list):
    rings = [] # list of LineString that are closed loops
    open_lines = [] # list of open LineString
    # primero polygonize desde la union de las líneas (para formar polígonos con huecos)
    try:
        u = unary_union(merged_list)
        polys = list(polygonize(u))
    except Exception:
        polys = []
    # If polygonize found polygons, extract their exterior and interiors as rings:
    for p in polys:
        try:
            ext = LineString(p.exterior.coords)
            if ext.length > MIN_RING_LEN:
                rings.append(ext)
        except Exception:
            pass
        # interiores (holes)
        for hole in p.interiors:
            try:
                h = LineString(hole.coords)
                if h.length > MIN_RING_LEN:
                    rings.append(h)
            except Exception:
                pass
    # ahora los merged_list originales: si son rings añádelos (si no ya fueron capturados)
    for g in merged_list:
        try:
            coords = list(g.coords)
            if len(coords) >= 4 and (np.allclose(coords[0], coords[-1]) or g.is_ring):
                # cerrado
                if g.length > MIN_RING_LEN:
                    # comprobar si similar a algún ring ya capturado (evitar duplicados)
                    dup = False
                    for r in rings:
                        if abs(r.length - g.length) < 1e-6 and Point(r.centroid).distance(Point(g.centroid)) < 1e-6:
                            dup = True
                            break
                    if not dup:
                        rings.append(LineString(g.coords))
                else:
                    # muy pequeño -> ignorar
                    pass
            else:
                open_lines.append(g)
        except Exception:
            open_lines.append(g)
    return rings, open_lines

rings_cortar, open_cortar = extract_rings_and_openlines(merged_cortar)
rings_nocortar, open_nocortar = extract_rings_and_openlines(merged_nocortar)

print(f"🔁 Rings (cerrados) detectar: cortar={len(rings_cortar)}, no_cortar={len(rings_nocortar)}")
print(f"⚡ Líneas abiertas: cortar={len(open_cortar)}, no_cortar={len(open_nocortar)}")

# -------------------------------------------------------------
# 6️⃣ CREAR POLYGONOS (para test de contención) a partir de rings
#    APLICACIÓN DE SIMPLIFICACIÓN AQUÍ PARA MAYOR VELOCIDAD
# -------------------------------------------------------------
def ring_to_polygon(ring_ls, tolerance=SIMPLIFY_TOLERANCE):
    try:
        coords = list(ring_ls.coords)
        # si el ring no está cerrado, cerrarlo
        if not np.allclose(coords[0], coords[-1]):
            coords = coords + [coords[0]]
        poly = Polygon(coords)

        # *** OPTIMIZACIÓN DE VELOCIDAD ***
        if tolerance > 0:
            poly = poly.simplify(tolerance, preserve_topology=True)
        # **********************************

        if not poly.is_valid:
            poly = poly.buffer(0) # intento de saneamiento
        if poly.is_valid and poly.area > 0:
            return poly
    except Exception as e:
        # print(f"⚠️ Error al convertir a polígono: {e}") # Descomentar para debug
        pass
    return None

polys_cortar = []
ring_to_poly_map = {} # map polygon -> original ring
for r in rings_cortar:
    p = ring_to_polygon(r)
    if p is not None:
        polys_cortar.append(p)
        ring_to_poly_map[id(p)] = r

# -------------------------------------------------------------
# 7️⃣ DETECTAR JERARQUÍAS (PADRE-HIJO) entre polígonos/cierres
# -------------------------------------------------------------
def build_supergroups(polys):
    n = len(polys)
    parents = [-1]*n
    areas = [polys[i].area for i in range(n)]
    for i in range(n):
        # buscar contenedores de polys[i]
        candidates = []
        pi = polys[i]
        # representative point for robust within check
        rep = pi.representative_point()
        for j in range(n):
            if i == j: continue
            pj = polys[j]
            # si pj contiene el punto representativo de pi -> pj es candidato a padre
            if pj.contains(rep):
                candidates.append((areas[j], j))
        if candidates:
            # elegir el padre con menor area que aún contenga (es el más cercano)
            candidates.sort()
            parents[i] = candidates[0][1]
    # construir árbol de grupos: cada root (parent == -1) define un supergrupo
    supergroups = {}
    for i in range(n):
        # ascender hasta la raiz
        root = i
        while parents[root] != -1:
            root = parents[root]
        if root not in supergroups:
            supergroups[root] = []
        supergroups[root].append(i)
    return supergroups, parents

supergroups_cortar, parents_cortar = build_supergroups(polys_cortar)
print(f"✅ Jerarquía calculada. Tiempo consumido en {len(polys_cortar)} polígonos.") # <--- MENSAJE DE DIAGNÓSTICO
print(f"📂 Supergrupos detectados (polígonos cortar): {len(supergroups_cortar)}")

# -------------------------------------------------------------
# 8️⃣ FORMATEAR SUPERGRUPOS: convertir índices a LineStrings (contornos)
# -------------------------------------------------------------
def poly_index_to_contours(poly_indices, polys, ring_map):
    contours = []
    for idx in poly_indices:
        p = polys[idx]
        # exterior
        try:
            ext_ring = LineString(p.exterior.coords)
            contours.append(ext_ring)
        except Exception:
            pass
        # holes
        for hole in p.interiors:
            try:
                hole_ls = LineString(hole.coords)
                contours.append(hole_ls)
            except Exception:
                pass
    return contours

# construir lista de supergrupos con sus contornos ordenados
supergroup_contours = []
for root, members in supergroups_cortar.items():
    contours = poly_index_to_contours(members, polys_cortar, ring_to_poly_map)
    # ordenar por longitud (asc)
    contours_sorted = sorted(contours, key=lambda c: c.length)
    supergroup_contours.append(contours_sorted)

# -------------------------------------------------------------
# 9️⃣ AÑADIR RINGS QUE NO FORMARON PARTE DE NINGÚN polígono (casos aislados)
# -------------------------------------------------------------
# id set of rings already in polys
polys_rings_ids = set()
for idx, p in enumerate(polys_cortar):
    polys_rings_ids.add(id(ring_to_poly_map[id(p)]))

# collect rings that were not polygonized -> compare by centroid/length
remaining_rings = []
for r in rings_cortar:
    # check if similar ring exists in already used polygons
    used = False
    for p in polys_cortar:
        r_used = ring_to_poly_map.get(id(p), None)
        if r_used is None:
            continue
        if abs(r_used.length - r.length) < 1e-6 and Point(r.centroid).distance(Point(r_used.centroid)) < 1e-6:
            used = True
            break
    if not used:
        remaining_rings.append(r)

# add each remaining ring as its own supergroup (single contour)
for r in remaining_rings:
    supergroup_contours.append([r])

# -------------------------------------------------------------
# 10️⃣ LÍNEAS ABIERTAS Y POLILÍNEAS NO-ANIDADAS:
# -------------------------------------------------------------
# open_cortar contiene líneas abiertas resultado de la unión
open_groups = [[ln] for ln in sorted(open_cortar, key=lambda l: l.length)]

# -------------------------------------------------------------
# 11️⃣ CREAR SECUENCIA FINAL DE CORTE:
# -------------------------------------------------------------
final_cut_sequence = []
# añadir supergrupos
for sg in supergroup_contours:
    # sg ya está ordenado internamente (short->long)
    final_cut_sequence.append(sg)

# añadir open groups
for og in open_groups:
    final_cut_sequence.append(og)

print(f"🔢 Secuencia de corte (grupos): {len(final_cut_sequence)}")

# -------------------------------------------------------------
# 12️⃣ PREPARAR SECUENCIA NO_CORTAR (similar, pero no afecta nesting)
# -------------------------------------------------------------
final_nocut_sequence = []
# attempt to create rings for no-cut too
for r in rings_nocortar:
    final_nocut_sequence.append([r])
for ln in sorted(open_nocortar, key=lambda l: l.length):
    final_nocut_sequence.append([ln])
print(f"ℹ️ Secuencia NO_CORTAR (grupos): {len(final_nocut_sequence)}")

# -------------------------------------------------------------
# 13️⃣ GRAFICAR RESULTADO (para ver jerarquía y orden)
# -------------------------------------------------------------
plt.figure(figsize=(9,9))
# colors: supergroups (CORTAR) - draw interior contours first with dotted for visibility
for gi, sg in enumerate(final_cut_sequence):
    for ci, contour in enumerate(sg):
        x, y = contour.xy
        # interiores (más cortos) pintarlos con azul, exterior con green
        if ci < len(sg)-1:
            plt.plot(x, y, linestyle='--', linewidth=1.3, label="CORTAR (interior)" if gi==0 and ci==0 else "")
        else:
            plt.plot(x, y, linestyle='-', linewidth=1.7, label="CORTAR (exterior)" if gi==0 else "")
# open groups already included above
# ahora no cortar
for i, sg in enumerate(final_nocut_sequence):
    for contour in sg:
        x, y = contour.xy
        plt.plot(x, y, linestyle=':', linewidth=1.2, label="NO_CORTAR" if i==0 else "")

plt.axis('equal')
plt.title("🧩 Jerarquía & Orden de Corte (interior primero → exterior último)")
plt.xlabel("X [mm]")
plt.ylabel("Y [mm]")
plt.grid(True)
plt.legend()
plt.show()

# -------------------------------------------------------------
# 14️⃣ EXPORTAR TODO EN UN SOLO TXT (orden correcto)
# -------------------------------------------------------------
def export_sequence_to_txt(filename, cut_seq, nocut_seq, export_in_meters=EXPORT_IN_METERS):
    factor = 0.001 if export_in_meters else 1.0
    out = io.StringIO()
    out.write("# X Y Z CUT_FLAG\n")
    # cortar primero según sequence (cada grupo puede tener varias cadenas; cada cadena es LineString)
    for gidx, group in enumerate(cut_seq):
        for chain in group:
            x, y = chain.xy
            for xi, yi in zip(x, y):
                out.write(f"{xi*factor:.6f} {yi*factor:.6f} 0.000 1\n")
            # separador de cadena
            out.write("NaN NaN NaN NaN\n")
        # separador de grupo (opcional, ya tenemos NaN)
    # luego objetos NO_CORTAR
    for gidx, group in enumerate(nocut_seq):
        for chain in group:
            x, y = chain.xy
            for xi, yi in zip(x, y):
                out.write(f"{xi*factor:.6f} {yi*factor:.6f} 0.000 0\n")
            out.write("NaN NaN NaN NaN\n")
    # escribir archivo y lanzar descarga
    content = out.getvalue()
    with open(filename, 'w') as f:
        f.write(content)
    print(f"✅ Exportado: {filename}  (en metros: {export_in_meters})")
    #files.download(filename)

export_sequence_to_txt("TrayectoriaScaraCnc_PRO.txt", final_cut_sequence, final_nocut_sequence, EXPORT_IN_METERS)

print("Proceso completado. Descarga lista para MATLA")