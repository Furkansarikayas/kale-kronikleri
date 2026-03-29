"""
Convert all JPG files in assets/images/ to transparent PNG using rembg.
Handles filenames like 'fire_t4b.jpg' -> 'fire_t4b.png'
Skips if PNG already exists and is newer than the JPG.
"""
import sys
import os
from pathlib import Path
from PIL import Image
from rembg import remove

ASSETS_DIR = Path(__file__).parent.parent / "assets" / "images"

def convert_all():
    jpg_files = list(ASSETS_DIR.rglob("*.jpg"))
    if not jpg_files:
        print("No JPG files found.")
        return

    print(f"Found {len(jpg_files)} JPG files")
    for jpg_path in sorted(jpg_files):
        # Strip all .jpg/.png suffixes and add .png
        stem = jpg_path.stem
        while stem.endswith('.png') or stem.endswith('.jpg'):
            stem = stem[:-4]
        png_path = jpg_path.parent / f"{stem}.png"

        # Skip if PNG exists and is newer
        if png_path.exists() and png_path.stat().st_mtime > jpg_path.stat().st_mtime:
            print(f"  SKIP {jpg_path.relative_to(ASSETS_DIR)} (PNG up to date)")
            continue

        print(f"  CONVERT {jpg_path.relative_to(ASSETS_DIR)} -> {png_path.name} ...", end=" ", flush=True)
        try:
            img = Image.open(jpg_path)
            result = remove(img)
            result.save(png_path)
            print("OK")
        except Exception as e:
            print(f"FAIL: {e}")

    print("\nDone!")

if __name__ == "__main__":
    convert_all()
