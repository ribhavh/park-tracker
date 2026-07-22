#!/usr/bin/env python3
"""Fetch Central Park walking paths from OpenStreetMap (Overpass API) and
write them as a GeoJSON FeatureCollection of LineStrings.

Each feature is one OSM way with properties: wayId, name, highway.
Segmentation into ~20 m pieces happens at runtime in the app (ParkData.swift),
so this file stays a faithful, regenerable copy of the raw OSM geometry.

Usage:
    python3 Scripts/fetch_paths.py            # writes ParkTracker/Resources/centralpark_paths.geojson
    python3 Scripts/fetch_paths.py out.geojson
"""
import json
import sys
import urllib.request
import urllib.error

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Restrict to the Central Park green space polygon, then pull pedestrian ways
# inside it. `out geom;` returns inline coordinates for each way.
QUERY = r"""
[out:json][timeout:120];
area["leisure"="park"]["name"="Central Park"]["wikidata"="Q160409"]->.cp;
(
  way["highway"~"^(footway|path|pedestrian|steps|track)$"](area.cp);
);
out geom;
"""

# Fallback: if the wikidata-tagged area lookup returns nothing (tag drift),
# use a bounding box around Central Park instead.
QUERY_BBOX = r"""
[out:json][timeout:120];
(
  way["highway"~"^(footway|path|pedestrian|steps|track)$"](40.7644,-73.9819,40.8006,-73.9493);
);
out geom;
"""


def run_query(query: str) -> dict:
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(
        OVERPASS_URL,
        data=data,
        headers={
            "User-Agent": "park-tracker/1.0 (Central Park path fetch)",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode())


def to_geojson(overpass: dict) -> dict:
    features = []
    for el in overpass.get("elements", []):
        if el.get("type") != "way":
            continue
        geom = el.get("geometry")
        if not geom or len(geom) < 2:
            continue
        # GeoJSON is [lon, lat]
        coords = [[pt["lon"], pt["lat"]] for pt in geom]
        tags = el.get("tags", {})
        features.append({
            "type": "Feature",
            "properties": {
                "wayId": el["id"],
                "name": tags.get("name", ""),
                "highway": tags.get("highway", ""),
            },
            "geometry": {"type": "LineString", "coordinates": coords},
        })
    return {"type": "FeatureCollection", "features": features}


def main() -> int:
    import urllib.parse  # noqa: F401 (used in run_query)
    out_path = sys.argv[1] if len(sys.argv) > 1 else \
        "ParkTracker/Resources/centralpark_paths.geojson"

    print("Querying Overpass (Central Park area)...", file=sys.stderr)
    result = run_query(QUERY)
    if not result.get("elements"):
        print("Area query empty; retrying with bounding box...", file=sys.stderr)
        result = run_query(QUERY_BBOX)

    fc = to_geojson(result)
    n = len(fc["features"])
    if n == 0:
        print("ERROR: no path features returned.", file=sys.stderr)
        return 1

    with open(out_path, "w") as f:
        json.dump(fc, f)
    print(f"Wrote {n} path ways -> {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    import urllib.parse
    sys.exit(main())
