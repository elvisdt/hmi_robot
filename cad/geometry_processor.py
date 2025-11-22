import math

def densify(points, max_dist=1.0):
    """Given a list of 2D points, densify segments so no gap > max_dist"""
    out = []
    for i in range(len(points)-1):
        a = points[i]; b = points[i+1]
        out.append(a)
        dx = b[0]-a[0]; dy = b[1]-a[1]
        dist = math.hypot(dx, dy)
        if dist > max_dist:
            steps = int(math.ceil(dist / max_dist))
            for s in range(1, steps):
                t = s/steps
                out.append((a[0]+dx*t, a[1]+dy*t))
    out.append(points[-1])
    return out

def normalize_sequence(seq, scale=1.0, translate=(0,0)):
    tx, ty = translate
    return [((x*scale)+tx, (y*scale)+ty) for (x,y) in seq]
