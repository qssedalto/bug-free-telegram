#!/usr/bin/env bash
# Reuse the official AERTEX source mark for xtool, Xcode iOS and watchOS.
# Run with: bash CI/prepare_xtool.sh
set -euo pipefail

cd "$(dirname "$0")/.."
python_executable="${PYTHON3:-python3}"
venv="${XDG_CACHE_HOME:-$HOME/.cache}/aertex/brand-venv"
if [[ ! -x "$venv/bin/python" ]]; then
    "$python_executable" -m venv "$venv"
fi
if ! "$venv/bin/python" -c 'from PIL import Image' >/dev/null 2>&1; then
    "$venv/bin/python" -m pip install --disable-pip-version-check 'Pillow>=10,<14'
fi

"$venv/bin/python" CI/render_brand_assets.py

"$venv/bin/python" - <<'PY'
from pathlib import Path
from PIL import Image, ImageChops
from hashlib import sha256

root = Path.cwd()
phone = root / "CI/GeneratedAssets.xcassets/AppIcon.appiconset/AppIcon1024.png"
watch = root.parent / "watchOS/AERTEXWatch/GeneratedAssets.xcassets/AppIcon.appiconset/AppIcon1024.png"
legacy = root / "Build/AppIcons/AppIcon1024.png"
config = (root / "xtool.yml").read_text(encoding="utf-8")
assert "iconPath: CI/GeneratedAssets.xcassets/AppIcon.appiconset/AppIcon1024.png" in config, (
    "xtool is not configured to use the generated AERTEX icon"
)
assert phone.is_file() and watch.is_file(), "generated iOS/Watch icon is missing"
with Image.open(phone) as icon, Image.open(watch) as watch_icon:
    assert icon.size == (1024, 1024) and icon.mode == "RGB", "iPhone icon must be opaque 1024x1024 RGB"
    assert watch_icon.size == (1024, 1024), "Watch icon must be 1024x1024"
    assert sha256(phone.read_bytes()).digest() == sha256(watch.read_bytes()).digest(), (
        "iOS and watchOS icon artwork differs"
    )
    if legacy.exists():
        with Image.open(legacy) as old:
            assert ImageChops.difference(icon.convert("RGB"), old.convert("RGB")).getbbox(), (
                "generated AERTEX icon unexpectedly matches the obsolete 是否认同 icon"
            )
print(f"AERTEX icon verified for xtool + Xcode + Watch: {phone}")
PY
