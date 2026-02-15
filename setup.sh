#!/usr/bin/env bash
set -euo pipefail

# This script prepares everything so that:
#   docker compose up -d
# succeeds with your existing docker-compose.yml.
#
# It DOES NOT start containers. It only downloads data + builds OTP graph + builds OSRM dataset.
#
# Assumes you run it in the same directory where docker-compose.yml lives.

# ---- Config (what we used) ----
WL_GTFS_URL="http://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs/gtfs.zip"
AUSTRIA_PBF_URL="https://download.geofabrik.de/europe/austria-latest.osm.pbf"

OTP_IMAGE="opentripplanner/opentripplanner:latest"
OSRM_IMAGE="ghcr.io/project-osrm/osrm-backend:latest"

# Must match your compose OTP heap (JAVA_TOOL_OPTIONS: "-Xmx10g")
OTP_XMX="10g"

# ---- Folders expected by compose ----
OTP_DIR="./otp"
OSRM_DIR="./osrm"
DATA_DIR="./data"

echo "==> Working dir: $(pwd)"
test -f docker-compose.yml || { echo "ERROR: docker-compose.yml not found in $(pwd)"; exit 1; }

mkdir -p "$OTP_DIR" "$OSRM_DIR" "$DATA_DIR"

echo "==> Downloading Austria OSM PBF..."
curl -L "$AUSTRIA_PBF_URL" -o "$DATA_DIR/austria.osm.pbf"

echo "==> Downloading Wiener Linien GTFS zip..."
# Use UA because WL sometimes behaves better with it
curl -L -A "Mozilla/5.0" "$WL_GTFS_URL" -o "$OTP_DIR/wl-gtfs.zip"

echo "==> Preparing OTP inputs..."
# OTP docker docs expect the OSM file to be named osm.pbf in the mounted folder
cp -f "$DATA_DIR/austria.osm.pbf" "$OTP_DIR/osm.pbf"

# Enable actuator health endpoints via OTP feature flag (what you needed)
cat > "$OTP_DIR/otp-config.json" <<'JSON'
{
  "otpFeatures": {
    "ActuatorAPI": true
  }
}
JSON

echo "==> Ensuring OTP input filenames are compatible..."
# OTP needs GTFS filenames to include "gtfs" somewhere, so rename if needed
if [[ "$OTP_DIR/wl-gtfs.zip" != *gtfs* ]]; then
  mv -f "$OTP_DIR/wl-gtfs.zip" "$OTP_DIR/wl-gtfs.zip"
fi

# Clean previous graph outputs (so rebuild is deterministic)
rm -f "$OTP_DIR/graph.obj"
rm -rf "$OTP_DIR/graphs"

echo "==> Building OTP graph (WL only)..."
docker run --rm \
  -e "JAVA_TOOL_OPTIONS=-Xmx${OTP_XMX}" \
  -v "$(pwd)/otp:/var/opentripplanner" \
  "$OTP_IMAGE" \
  --build --save

echo "==> Preparing OSRM inputs..."
cp -f "$DATA_DIR/austria.osm.pbf" "$OSRM_DIR/austria.osm.pbf"

echo "==> Building OSRM (car, MLD) dataset..."
docker run --rm -t \
  -v "$(pwd)/osrm:/data" \
  "$OSRM_IMAGE" \
  osrm-extract -p /opt/car.lua /data/austria.osm.pbf

docker run --rm -t \
  -v "$(pwd)/osrm:/data" \
  "$OSRM_IMAGE" \
  osrm-partition /data/austria.osrm

docker run --rm -t \
  -v "$(pwd)/osrm:/data" \
  "$OSRM_IMAGE" \
  osrm-customize /data/austria.osrm

echo
echo "==> Setup complete."
echo "Now run:"
echo "  docker compose up -d"
echo
echo "Sanity checks after compose is up:"
echo "  OTP:  http://<VM_IP>:9090/"
echo "  OTP health (enabled): http://<VM_IP>:9090/actuators/health (or /otp/actuators/health)"
echo "  OSRM API: http://<VM_IP>:5000/route/v1/driving/16.3738,48.2082;16.35,48.20?overview=false"
echo "  OSRM UI: http://<VM_IP>:9966/"
