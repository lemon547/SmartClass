"""Generate launcher icons: large cap, no inner border."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "assets" / "icons"
SIZE = 1024
# Adaptive icon safe zone ~66%; cap fills most of it.
CAP_SCALE = 0.58


def _cap_points(cx: float, cy: float, scale: float) -> list[tuple[float, float]]:
    """Lucide graduation-cap paths, scaled and centered."""
    s = scale

    def p(x: float, y: float) -> tuple[float, float]:
        return (cx + (x - 12) * s, cy + (y - 12) * s)

    top = [
        p(21.42, 10.922),
        p(21.401, 9.084),
        p(12.83, 5.18),
        p(11.17, 5.18),
        p(2.6, 9.08),
        p(2.6, 10.912),
        p(11.17, 14.816),
        p(12.83, 14.816),
    ]
    tassel = [p(22, 10), p(22, 16)]
    base_left = [p(6, 12.5), p(6, 16)]
    base_right = [p(18, 12.5), p(18, 16)]
    return top, tassel, base_left, base_right


def _draw_cap(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    scale: float,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    top, tassel, base_left, base_right = _cap_points(cx, cy, scale)
    draw.line(top + [top[0]], fill=color, width=width, joint="curve")
    draw.line(tassel, fill=color, width=width, joint="curve")
    draw.line(base_left, fill=color, width=width, joint="curve")
    draw.line(base_right, fill=color, width=width, joint="curve")
    # Mortarboard base arc (approximate Lucide path)
    bx, by = cx, cy + 4 * scale
    rx, ry = 6 * scale, 2.2 * scale
    arc_pts: list[tuple[float, float]] = []
    for i in range(33):
        t = math.pi + i / 32 * math.pi
        arc_pts.append((bx + rx * math.cos(t), by + ry * math.sin(t)))
    draw.line(arc_pts, fill=color, width=width, joint="curve")


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _render_cap_rgba(stroke: int) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    scale = SIZE * CAP_SCALE / 24
    _draw_cap(draw, SIZE / 2, SIZE / 2, scale, (0, 0, 0, 255), stroke)
    return img


def main() -> None:
    ICONS.mkdir(parents=True, exist_ok=True)
    stroke = max(24, int(SIZE * 0.028))

    # Foreground: transparent + large cap (Android adaptive)
    fg = _render_cap_rgba(stroke)
    fg_path = ICONS / "app_icon_foreground.png"
    fg.save(fg_path, "PNG")
    print(f"Wrote {fg_path}")

    # Full icon: white squircle, no inner border
    full = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    cap = _render_cap_rgba(stroke)
    full = Image.alpha_composite(full, cap)
    mask = _rounded_mask(SIZE, int(SIZE * 0.22))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(full, mask=mask)
    icon_path = ICONS / "app_icon.png"
    out.convert("RGB").save(icon_path, "PNG")
    print(f"Wrote {icon_path}")


if __name__ == "__main__":
    main()
