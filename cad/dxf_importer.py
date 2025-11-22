# Simple DXF importer stub using ezdxf
# This file provides a helper to extract polylines and lines as lists of 2D points.
# Real projects should add error handling and support more entities.

try:
    import ezdxf
except Exception as e:
    ezdxf = None

def extract_points_from_dxf(path, layer_filter=None):
    """Return list of point sequences: [ [(x,y),...], ... ]"""
    if ezdxf is None:
        raise RuntimeError("ezdxf is not installed. Install with pip install ezdxf")
    doc = ezdxf.readfile(path)
    msp = doc.modelspace()
    sequences = []
    # Lines
    for e in msp.query('LINE'):
        if layer_filter and e.dxf.layer not in layer_filter: continue
        x1, y1, _ = e.dxf.start
        x2, y2, _ = e.dxf.end
        sequences.append([(x1, y1), (x2, y2)])
    # LWPOLYLINE and POLYLINE
    for e in msp.query('LWPOLYLINE'):
        if layer_filter and e.dxf.layer not in layer_filter: continue
        pts = [(pt[0], pt[1]) for pt in e.get_points()]
        sequences.append(pts)
    for e in msp.query('POLYLINE'):
        if layer_filter and e.dxf.layer not in layer_filter: continue
        pts = [(v.x, v.y) for v in e.vertices()]
        sequences.append(pts)
    return sequences
