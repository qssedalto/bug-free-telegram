#!/usr/bin/env python3
"""Rasterize the exact website A mark and AERTEX SVG wordmark for Apple assets.

Sources in this repo are copied verbatim from qssedalto/qssed.studio:
  studio/brand-logo.js -> Resources/AERTEXMark.png
  AERTEX_WORDMARK_SVG -> Resources/AERTEXWordmark.svg
App artwork is derived; do not substitute typography or recolor its contours.
"""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources" / "是否认同" / "Resources"
IOS_ASSETS = ROOT / "CI" / "GeneratedAssets.xcassets"
WATCH_ASSETS = ROOT.parent / "watchOS" / "AERTEXWatch" / "GeneratedAssets.xcassets"

def write_image_set(folder: Path, name: str, image: Image.Image, scale: str = "1x") -> None:
    where = folder / (name + ".imageset")
    where.mkdir(parents=True, exist_ok=True)
    image.save(where / (name + ".png"), "PNG")
    (where / "Contents.json").write_text(json.dumps({
        "images": [{
            "filename": name + ".png", "idiom": "universal", "scale": scale
        }],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"}
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def original_mark() -> Image.Image:
    img = Image.open(RES / "AERTEXMark.png").convert("RGBA")
    alpha = img.getchannel("A")
    if alpha.getextrema() == (255, 255):
        # Some exported A logos are opaque white with dark ink.
        alpha = ImageOps.invert(ImageOps.grayscale(img))
    elif alpha.getextrema()[0] > 0:
        alpha = ImageChops.multiply(alpha, ImageOps.invert(ImageOps.grayscale(img)))
    # A site logo is a stencil. Template rendering adapts its color to the UI.
    result = Image.new("RGBA", img.size, (18, 20, 23, 0))
    result.putalpha(alpha)
    bbox = result.getbbox()
    if bbox is None:
        raise RuntimeError("Website A mark has no visible pixels")
    return result.crop(bbox)

def app_icon(mark: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    glyph = mark.copy()
    glyph.thumbnail((820, 820), Image.Resampling.LANCZOS)
    mask = glyph.getchannel("A")
    dark = Image.new("RGBA", glyph.size, (18, 20, 23, 255))
    canvas.paste(dark, ((1024 - glyph.width) // 2,
                        (1024 - glyph.height) // 2), mask)
    return canvas.convert("RGB")

def wordmark(size: tuple[int, int]) -> Image.Image:
    tree = ET.parse(RES / "AERTEXWordmark.svg")
    root = tree.getroot()
    paths = [node.attrib.get("d", "") for node in root.iter()
             if node.tag.endswith("path")]
    if len(paths) != 1:
        raise RuntimeError("Expected website SVG to have a single wordmark path")
    parts = re.findall(r"[MLZ]|-?\d+(?:\.\d+)?", paths[0])
    polygons = []
    current = []
    i = 0
    while i < len(parts):
        operation = parts[i]
        i += 1
        if operation == "Z":
            if current:
                polygons.append(current)
                current = []
            continue
        if operation not in ("M", "L") or i + 1 >= len(parts):
            raise RuntimeError("Unexpected website SVG path instruction")
        if operation == "M" and current:
            polygons.append(current)
            current = []
        current.append((float(parts[i]), float(parts[i + 1])))
        i += 2
    if current:
        polygons.append(current)
    if len(polygons) != 8:
        raise RuntimeError(f"Unexpected website wordmark outline: {len(polygons)}")
    width, height = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    painter = ImageDraw.Draw(image)
    for polygon in polygons:
        painter.polygon([(round(x * width / 1027),
                          round(y * height / 198)) for x, y in polygon],
                        fill=(18, 20, 23, 255))
    return image

def main() -> None:
    mark = original_mark()
    icon = app_icon(mark)
    for folder in (IOS_ASSETS, WATCH_ASSETS):
        folder.mkdir(parents=True, exist_ok=True)
        icon_dir = folder / "AppIcon.appiconset"
        icon_dir.mkdir(parents=True, exist_ok=True)
        icon.save(icon_dir / "AppIcon1024.png", "PNG")
        (icon_dir / "Contents.json").write_text(json.dumps({
            "images": [{
                "filename": "AppIcon1024.png",
                "idiom": "universal",
                "platform": "watchos" if folder == WATCH_ASSETS else "ios",
                "size": "1024x1024"
            }],
            "info": {"author": "xcode", "version": 1}
        }, indent=2) + "\n", encoding="utf-8")
        write_image_set(folder, "AERTEXMark", mark)
        write_image_set(folder, "AERTEXWordmarkInline",
                        wordmark((312, 60)), scale="3x")
    print("Verified website-derived assets: A mark, wordmark, iOS/watchOS icons")

if __name__ == "__main__":
    main()
