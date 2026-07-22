#!/usr/bin/env python3
"""Fetch the Central Park outline from OpenStreetMap (Overpass) and write it as
a GeoJSON Polygon (outer ring) used for "am I inside the park?" checks and to
draw the park boundary on the map.

Usage:
    python3 Scripts/fetch_boundary.py     # -> ParkTracker/Resources/centralpark_boundary.geojson
"""
import json
import sys
import urllib.parse
import urllib.request

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
OUT = sys.argv[1] if len(sys.argv) > 1 else \
    "ParkTracker/Resources/centralpark_boundary.geojson"

# The Central Park green space, identified by its Wikidata id (stable).
QUERY = r"""
[out:json][timeout:120];
(
  way["leisure"="park"]["wikidata"="Q160409"];
  relation["leisure"="park"]["wikidata"="Q160409"];
);
out geom;
"""


def run(query):
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(OVERPASS_URL, data=data, headers={
        "User-Agent": "park-tracker/1.0 (Central Park boundary fetch)",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode())


def ring_from_way(way):
    return [[p["lon"], p["lat"]] for p in way.get("geometry", [])]


def main():
    print("Querying Overpass (Central Park outline)...", file=sys.stderr)
    result = run(QUERY)
    elements = result.get("elements", [])

    ring = None
    # Prefer a single closed way.
    for el in elements:
        if el.get("type") == "way" and el.get("geometry"):
            r = ring_from_way(el)
            if len(r) >= 4:
                ring = r
                break
    # Otherwise stitch the relation's outer members into the longest ring.
    if ring is None:
        best = []
        for el in elements:
            if el.get("type") != "relation":
                continue
            for m in el.get("members", []):
                if m.get("role") == "outer" and m.get("geometry"):
                    r = [[p["lon"], p["lat"]] for p in m["geometry"]]
                    if len(r) > len(best):
                        best = r
        ring = best if len(best) >= 4 else None

    if not ring:
        print("ERROR: could not extract a boundary ring.", file=sys.stderr)
        return 1

    # Close the ring if needed.
    if ring[0] != ring[-1]:
        ring.append(ring[0])

    fc = {
        "type": "FeatureCollection",
        "features": [{
            "type": "Feature",
            "properties": {"name": "Central Park"},
            "geometry": {"type": "Polygon", "coordinates": [ring]},
        }],
    }
    with open(OUT, "w") as f:
        json.dump(fc, f)
    print(f"Wrote boundary ring ({len(ring)} points) -> {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
