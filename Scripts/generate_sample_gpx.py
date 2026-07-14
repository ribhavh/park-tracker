#!/usr/bin/env python3
"""Generate a realistic ~2 km walking route along real Central Park paths and
write it as a GPX track for Xcode's Simulator location simulation.

It builds a graph from the bundled path geometry (snapping nearby endpoints),
then greedily walks connected edges from a chosen start, sampling a point every
few meters so the app's coverage engine lights up the segments as it "walks".

Usage:
    python3 Scripts/generate_sample_gpx.py            # -> Sample/central_park_walk.gpx
"""
import json
import math
import sys
from collections import defaultdict

GEOJSON = "ParkTracker/Resources/centralpark_paths.geojson"
OUT = sys.argv[1] if len(sys.argv) > 1 else "Sample/central_park_walk.gpx"

# Roughly the Grand Army Plaza / SE-corner entrance — a natural place to start.
START_NEAR = (40.7666, -73.9727)
TARGET_METERS = 2000.0
SAMPLE_METERS = 8.0
SNAP_METERS = 4.0


def meters(a, b):
    (lat1, lon1), (lat2, lon2) = a, b
    mlat = 111_320.0
    mlon = 111_320.0 * math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot((lat2 - lat1) * mlat, (lon2 - lon1) * mlon)


def snap_key(pt):
    mlat = 111_320.0
    mlon = 111_320.0 * math.cos(math.radians(pt[0]))
    return (round(pt[0] * mlat / SNAP_METERS), round(pt[1] * mlon / SNAP_METERS))


def main():
    fc = json.load(open(GEOJSON))
    # Graph: node key -> list of (neighbor_key, polyline points a..b)
    adj = defaultdict(list)
    node_pt = {}
    for feat in fc["features"]:
        coords = [(c[1], c[0]) for c in feat["geometry"]["coordinates"]]  # (lat, lon)
        for i in range(len(coords) - 1):
            a, b = coords[i], coords[i + 1]
            ka, kb = snap_key(a), snap_key(b)
            node_pt.setdefault(ka, a)
            node_pt.setdefault(kb, b)
            adj[ka].append((kb, [a, b]))
            adj[kb].append((ka, [b, a]))

    def bearing(a, b):
        return math.atan2(b[1] - a[1], b[0] - a[0])

    def angle_diff(x, y):
        d = abs(x - y) % (2 * math.pi)
        return min(d, 2 * math.pi - d)

    # Pick the start node closest to START_NEAR.
    start = min(node_pt, key=lambda k: meters(node_pt[k], START_NEAR))

    # Flowing trail: never repeat an edge; at each node keep going as straight as
    # possible (smallest turn) so the route spreads across the park instead of
    # doubling back. Stop when no fresh edge remains.
    used = set()
    route_pts = []
    cur = start
    heading = bearing(node_pt[start], START_NEAR)  # seed heading toward interior
    total = 0.0
    guard = 0
    while total < TARGET_METERS and guard < 100_000:
        guard += 1
        fresh = [(nb, pts) for nb, pts in adj[cur]
                 if frozenset((cur, nb)) not in used]
        if not fresh:
            break
        nb, pts = min(fresh, key=lambda e: angle_diff(
            bearing(e[1][0], e[1][1]), heading))
        used.add(frozenset((cur, nb)))
        heading = bearing(pts[0], pts[1])
        route_pts.append(pts[0])
        route_pts.append(pts[1])
        total += meters(pts[0], pts[1])
        cur = nb

    # Resample the polyline to one point every SAMPLE_METERS.
    sampled = [route_pts[0]]
    acc = 0.0
    for i in range(len(route_pts) - 1):
        a, b = route_pts[i], route_pts[i + 1]
        d = meters(a, b)
        if d == 0:
            continue
        steps = max(1, int(d / SAMPLE_METERS))
        for s in range(1, steps + 1):
            t = s / steps
            sampled.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))

    # Emit GPX using <wpt> elements (the form Xcode's location simulation reads),
    # timestamped ~6 s apart so it plays back at about walking pace.
    from datetime import datetime, timedelta, timezone
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<gpx version="1.1" creator="park-tracker" '
             'xmlns="http://www.topografix.com/GPX/1/1">']
    t0 = datetime(2026, 7, 13, 15, 0, 0, tzinfo=timezone.utc)
    for i, (lat, lon) in enumerate(sampled):
        ts = (t0 + timedelta(seconds=6 * i)).strftime("%Y-%m-%dT%H:%M:%SZ")
        lines.append(f'  <wpt lat="{lat:.6f}" lon="{lon:.6f}">'
                     f'<time>{ts}</time></wpt>')
    lines.append('</gpx>')
    open(OUT, "w").write("\n".join(lines))
    print(f"Wrote {len(sampled)} points (~{total:.0f} m walked) -> {OUT}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
