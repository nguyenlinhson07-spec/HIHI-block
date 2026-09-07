"""Generates the Hi Hi Block launcher icons and splash art.

Everything is drawn from scratch with Pillow using the game's own palette, so
the assets are original and match what the player sees in-game. Re-run with:

    python tool/generate_icons.py

Writes:
  android/app/src/main/res/mipmap-*/ic_launcher.png          (legacy icons)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  android/app/src/main/res/drawable*/splash_logo.png
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png        (no alpha)
  ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))

# --- Palette, straight from lib/core/theme/app_colors.dart -------------------
BG_TOP = (58, 42, 122)  # backgroundTop   #3A2A7A
BG_BOTTOM = (20, 15, 46)  # backgroundBottom #140F2E
BOARD_BG = (36, 26, 82)  # boardBackground #241A52
CYAN = (79, 209, 255)  # #4FD1FF
PINK = (255, 107, 157)  # #FF6B9D
GREEN = (126, 231, 135)  # #7EE787
GOLD = (255, 209, 102)  # #FFD166

# Supersampling factor: draw big, downscale with LANCZOS so small icons stay
# crisp instead of going jagged.
SS = 8


def vertical_gradient(size, top, bottom):
    """A smooth top-to-bottom gradient, like the in-game background."""
    image = Image.new("RGB", (1, size), top)
    pixels = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        pixels[0, y] = tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
        )
    return image.resize((size, size), Image.NEAREST)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def draw_blocks(canvas, origin, cell, gap, radius, layout):
    """Draws the little block cluster that is the mark itself.

    `layout` is a list of (row, column, colour) triples on a 3x3 grid.
    """
    draw = ImageDraw.Draw(canvas)
    for row, column, colour in layout:
        x = origin[0] + column * (cell + gap)
        y = origin[1] + row * (cell + gap)
        # A lighter top-left face gives the block the same soft 3D feel the
        # in-game tiles get from their gradient.
        draw.rounded_rectangle(
            (x, y, x + cell, y + cell),
            radius=radius,
            fill=tuple(min(255, round(c * 1.18)) for c in colour),
        )
        inset = cell * 0.17
        draw.rounded_rectangle(
            (x + inset, y + inset, x + cell, y + cell),
            radius=radius * 0.85,
            fill=colour,
        )


# The mark: four blocks in an S/Z-ish cluster on a 3x3 grid — recognisably a
# block-puzzle piece, and still readable at 48px.
MARK = [
    (0, 0, CYAN),
    (0, 1, PINK),
    (1, 1, GOLD),
    (1, 2, GREEN),
]


def render_mark(size, padding_ratio):
    """Transparent-background render of the mark, sized for `size` px.

    The cluster is centred on its own bounding box rather than on the 3x3
    grid it is described in — otherwise a shape that leaves a row empty ends
    up visibly pushed to one side.
    """
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    rows = [r for r, _, _ in MARK]
    columns = [c for _, c, _ in MARK]
    used_rows = max(rows) - min(rows) + 1
    used_columns = max(columns) - min(columns) + 1
    extent = max(used_rows, used_columns)

    pad = s * padding_ratio
    span = s - 2 * pad
    gap = span * 0.075
    cell = (span - (extent - 1) * gap) / extent
    radius = cell * 0.26

    def pitch(count):
        return count * cell + (count - 1) * gap

    origin = (
        pad + (span - pitch(used_columns)) / 2 - min(columns) * (cell + gap),
        pad + (span - pitch(used_rows)) / 2 - min(rows) * (cell + gap),
    )
    draw_blocks(layer, origin, cell, gap, radius, MARK)
    return layer.resize((size, size), Image.LANCZOS)


def icon(size, *, rounded, padding_ratio=0.18):
    """A complete icon: gradient ground plus the mark."""
    base = vertical_gradient(size * SS, BG_TOP, BG_BOTTOM).convert("RGBA")
    if rounded:
        base.putalpha(rounded_mask(size * SS, int(size * SS * 0.22)))
    base = base.resize((size, size), Image.LANCZOS)
    base.alpha_composite(render_mark(size, padding_ratio))
    return base


def adaptive_foreground(size):
    """Adaptive-icon foreground: the mark alone, inside the 66/108 safe zone.

    Android crops adaptive icons to whatever shape the launcher wants, so the
    mark has to sit well inside the canvas or corners get eaten.
    """
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    safe = round(size * 66 / 108)
    mark = render_mark(safe, padding_ratio=0.02)
    offset = (size - safe) // 2
    layer.alpha_composite(mark, (offset, offset))
    return layer


def flatten(image, background=BG_BOTTOM):
    """iOS icons must not carry an alpha channel."""
    flat = Image.new("RGB", image.size, background)
    flat.paste(image, mask=image.split()[3] if image.mode == "RGBA" else None)
    return flat


def save(image, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print(f"  {os.path.relpath(path, ROOT)}  {image.size[0]}x{image.size[1]}")


def main():
    res = ("android", "app", "src", "main", "res")

    print("Android legacy launcher icons:")
    for bucket, size in [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]:
        save(icon(size, rounded=True), *res, f"mipmap-{bucket}", "ic_launcher.png")

    print("Android adaptive foreground (108dp canvas):")
    for bucket, size in [
        ("mdpi", 108),
        ("hdpi", 162),
        ("xhdpi", 216),
        ("xxhdpi", 324),
        ("xxxhdpi", 432),
    ]:
        save(
            adaptive_foreground(size),
            *res,
            f"mipmap-{bucket}",
            "ic_launcher_foreground.png",
        )

    print("Splash logo:")
    for bucket, size in [
        ("mdpi", 96),
        ("hdpi", 144),
        ("xhdpi", 192),
        ("xxhdpi", 288),
        ("xxxhdpi", 384),
    ]:
        folder = "drawable" if bucket == "mdpi" else f"drawable-{bucket}"
        save(render_mark(size, padding_ratio=0.04), *res, folder, "splash_logo.png")

    print("iOS app icons (flattened, no alpha):")
    ios_icons = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_set = ("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for name, size in ios_icons.items():
        # iOS applies its own rounding, so the artwork stays square.
        save(flatten(icon(size, rounded=False)), *ios_set, name)

    print("iOS launch image:")
    launch = ("ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
    for name, size in [
        ("LaunchImage.png", 128),
        ("LaunchImage@2x.png", 256),
        ("LaunchImage@3x.png", 384),
    ]:
        save(render_mark(size, padding_ratio=0.04), *launch, name)


if __name__ == "__main__":
    main()
