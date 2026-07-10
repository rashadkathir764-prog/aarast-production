"""Generate Aarast launcher and native splash PNG assets.

The mark intentionally mirrors the in-app premium brand mark: royal burgundy,
champagne gold, ivory, and the four-point celebration sparkle. Run from any
working directory with Pillow available; outputs are deterministic.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

BURGUNDY = "#800020"
BURGUNDY_DARK = "#5A0015"
BURGUNDY_LIGHT = "#8E0B2C"
GOLD = "#D4AF37"
GOLD_DEEP = "#B8912A"
GOLD_LIGHT = "#F2D888"
IVORY = "#FCF8F5"


def _sparkle_points(
    center_x: float,
    center_y: float,
    outer_radius: float,
    inner_radius: float,
) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(16):
        angle = math.radians(-90 + index * 22.5)
        if index % 4 == 0:
            radius = outer_radius
        elif index % 2 == 0:
            radius = outer_radius * 0.48
        else:
            radius = inner_radius
        points.append(
            (
                center_x + math.cos(angle) * radius,
                center_y + math.sin(angle) * radius,
            )
        )
    return points


def _draw_mark(
    image: Image.Image,
    *,
    center: tuple[float, float],
    radius: float,
    splash: bool,
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    cx, cy = center

    # A restrained halo remains legible at notification-icon scale.
    for step in range(12, 0, -1):
        halo_radius = radius * (1.02 + step * 0.013)
        alpha = max(2, 22 - step)
        draw.ellipse(
            (
                cx - halo_radius,
                cy - halo_radius,
                cx + halo_radius,
                cy + halo_radius,
            ),
            fill=(212, 175, 55, alpha),
        )

    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=GOLD_DEEP,
    )
    draw.ellipse(
        (
            cx - radius * 0.925,
            cy - radius * 0.925,
            cx + radius * 0.925,
            cy + radius * 0.925,
        ),
        fill=GOLD_LIGHT,
    )
    draw.ellipse(
        (
            cx - radius * 0.82,
            cy - radius * 0.82,
            cx + radius * 0.82,
            cy + radius * 0.82,
        ),
        fill=BURGUNDY_DARK if splash else BURGUNDY,
    )

    sparkle_color = IVORY if splash else GOLD_LIGHT
    draw.polygon(
        _sparkle_points(cx, cy, radius * 0.55, radius * 0.10),
        fill=sparkle_color,
    )
    draw.ellipse(
        (
            cx - radius * 0.075,
            cy - radius * 0.075,
            cx + radius * 0.075,
            cy + radius * 0.075,
        ),
        fill=GOLD,
    )

    # Two smaller celebration sparks make the mark distinct without relying
    # on text that would become illegible at launcher-icon sizes.
    draw.polygon(
        _sparkle_points(
            cx + radius * 0.49,
            cy - radius * 0.42,
            radius * 0.15,
            radius * 0.035,
        ),
        fill=GOLD_LIGHT,
    )
    draw.polygon(
        _sparkle_points(
            cx - radius * 0.51,
            cy + radius * 0.46,
            radius * 0.105,
            radius * 0.028,
        ),
        fill=GOLD,
    )


def _app_icon_master() -> Image.Image:
    size = 1024
    vertical = Image.linear_gradient("L").resize((size, size))
    background = Image.merge(
        "RGB",
        (
            vertical.point(lambda value: 90 + value * 52 // 255),
            vertical.point(lambda value: value * 11 // 255),
            vertical.point(lambda value: 21 + value * 23 // 255),
        ),
    )
    radial = Image.radial_gradient("L").resize((size, size))
    glow = Image.new("RGB", (size, size), BURGUNDY_LIGHT)
    background = Image.composite(background, glow, radial.point(lambda v: v // 7))
    _draw_mark(background, center=(size / 2, size / 2), radius=278, splash=False)
    return background


def _splash_mark_master() -> Image.Image:
    size = 1024
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    _draw_mark(mark, center=(size / 2, size / 2), radius=300, splash=True)
    return mark


def _save_resized(source: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    if path.name == "Icon-App-1024x1024@1x.png":
        # App Store marketing icons must not contain alpha.
        resized = resized.convert("RGB")
    resized.save(path, format="PNG", optimize=True)


def main() -> None:
    app_icon = _app_icon_master()
    splash_mark = _splash_mark_master()

    android_icons = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
        "mipmap-mdpi/ic_launcher_round.png": 48,
        "mipmap-hdpi/ic_launcher_round.png": 72,
        "mipmap-xhdpi/ic_launcher_round.png": 96,
        "mipmap-xxhdpi/ic_launcher_round.png": 144,
        "mipmap-xxxhdpi/ic_launcher_round.png": 192,
    }
    android_res = ROOT / "android/app/src/main/res"
    for relative_path, size in android_icons.items():
        _save_resized(app_icon, android_res / relative_path, size)

    android_splash = {
        "drawable-mdpi/launch_image.png": 96,
        "drawable-hdpi/launch_image.png": 144,
        "drawable-xhdpi/launch_image.png": 192,
        "drawable-xxhdpi/launch_image.png": 288,
        "drawable-xxxhdpi/launch_image.png": 384,
    }
    for relative_path, size in android_splash.items():
        _save_resized(splash_mark, android_res / relative_path, size)

    ios_icon_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
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
    for filename, size in ios_icons.items():
        _save_resized(app_icon, ios_icon_dir / filename, size)

    ios_launch_dir = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for filename, size in {
        "LaunchImage.png": 168,
        "LaunchImage@2x.png": 336,
        "LaunchImage@3x.png": 504,
    }.items():
        _save_resized(splash_mark, ios_launch_dir / filename, size)

    print("Generated Aarast native launcher and splash assets.")


if __name__ == "__main__":
    main()
