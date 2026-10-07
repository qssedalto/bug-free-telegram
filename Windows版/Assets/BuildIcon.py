from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "AppIcon.png"
FINAL_PNG = ROOT / "AppIcon-final.png"
FINAL_ICO = ROOT / "AppIcon.ico"
PREVIEW = ROOT / "AppIcon-preview.png"
ICON_SIZES = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)


def prepare_master(source: Image.Image) -> Image.Image:
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("icon source contains no opaque pixels")
    cropped = rgba.crop(bounds)
    padding = max(24, round(max(cropped.size) * 0.065))
    side = max(cropped.size) + padding * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(
        cropped,
        ((side - cropped.width) // 2, (side - cropped.height) // 2),
    )
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


def checkerboard(size: tuple[int, int], cell: int = 20) -> Image.Image:
    image = Image.new("RGB", size, "white")
    draw = ImageDraw.Draw(image)
    colors = ((232, 232, 236), (196, 196, 202))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, x + cell - 1, y + cell - 1),
                fill=colors[((x // cell) + (y // cell)) % 2],
            )
    return image


def build_preview(master: Image.Image) -> Image.Image:
    preview = checkerboard((1180, 720), 24)
    large = master.resize((560, 560), Image.Resampling.LANCZOS)
    preview.paste(large, (70, 70), large)
    x = 700
    y = 100
    for size in (256, 128, 64, 48, 32, 24, 16):
        thumbnail = master.resize((size, size), Image.Resampling.LANCZOS)
        preview.paste(thumbnail, (x, y), thumbnail)
        y += size + 24
        if y + 256 > preview.height:
            x += 300
            y = 100
    return preview


def main() -> None:
    with Image.open(SOURCE) as source:
        master = prepare_master(source)
    master.save(FINAL_PNG, optimize=True)
    master.save(FINAL_ICO, format="ICO", sizes=[(size, size) for size in ICON_SIZES])
    build_preview(master).save(PREVIEW, optimize=True)


if __name__ == "__main__":
    main()
