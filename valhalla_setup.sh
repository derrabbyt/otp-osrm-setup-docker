#!/usr/bin/env bash
set -euo pipefail

# Run from repo root: ~/projects/routing-austria
BASE_DIR="$(pwd)"

PBF_SRC="$BASE_DIR/data/austria.osm.pbf"
GTFS_ZIP_SRC="$BASE_DIR/otp/wl-gtfs.zip"

VAL_DIR="$BASE_DIR/valhalla"
CUSTOM_DIR="$VAL_DIR/custom_files"
GTFS_DIR="$VAL_DIR/gtfs_feeds/wienerlinien"

# Sanity checks
[[ -f "$PBF_SRC" ]] || { echo "ERROR: Missing $PBF_SRC"; exit 1; }
[[ -f "$GTFS_ZIP_SRC" ]] || { echo "ERROR: Missing $GTFS_ZIP_SRC"; exit 1; }

echo "==> Creating Valhalla dirs..."
mkdir -p "$CUSTOM_DIR" "$GTFS_DIR"

echo "==> Copying PBF into Valhalla custom_files..."
cp -f "$PBF_SRC" "$CUSTOM_DIR/austria.osm.pbf"

echo "==> Refreshing Wiener Linien GTFS feed directory..."
rm -rf "$GTFS_DIR"/*
unzip -o "$GTFS_ZIP_SRC" -d "$GTFS_DIR" >/dev/null

echo "==> Done."
echo "PBF:  $CUSTOM_DIR/austria.osm.pbf"
echo "GTFS: $GTFS_DIR (unzipped)"
