from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BRAND_ROOT = ROOT / "App/ElvisWatchTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

FUTURA = "/System/Library/Fonts/Supplemental/Futura.ttc"
GILL_SANS = "/System/Library/Fonts/Supplemental/GillSans.ttc"
ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

PAPER = (241, 228, 199)
PAPER_SHADE = (223, 202, 170)
BLACK = (28, 20, 18)
WINE = (126, 31, 38)
CHERRY = (177, 54, 42)
GOLD = (227, 170, 73)
DARK_GOLD = (167, 115, 40)
TEAL = (49, 108, 117)
BLUE = (42, 61, 110)
OFF_WHITE = (255, 247, 233)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def add_paper_texture(image: Image.Image, seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(image)
    width, height = image.size

    for _ in range(max(120, width * height // 14000)):
        x = rng.randint(0, width - 1)
        y = rng.randint(0, height - 1)
        radius = rng.randint(1, max(2, min(width, height) // 180))
        color = rng.choice(
            [
                (255, 248, 234),
                (231, 214, 184),
                (215, 191, 154),
                (199, 168, 128),
            ]
        )
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def add_starburst(image: Image.Image, center: tuple[int, int], seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(image)
    width, height = image.size
    cx, cy = center

    for index in range(16):
        angle = index * 22.5
        spread = 12 if index % 2 == 0 else 6
        length = int(max(width, height) * (0.8 + rng.random() * 0.15))
        color = GOLD if index % 2 == 0 else CHERRY

        polygon = [(cx, cy)]
        polygon.extend(
            polar_polygon_points(cx, cy, angle - spread, angle + spread, length)
        )
        draw.polygon(polygon, fill=color)


def polar_polygon_points(
    cx: int, cy: int, start_angle: float, end_angle: float, length: int
) -> list[tuple[int, int]]:
    import math

    points: list[tuple[int, int]] = []
    for angle in (start_angle, end_angle):
        radians = math.radians(angle)
        x = int(cx + math.cos(radians) * length)
        y = int(cy + math.sin(radians) * length)
        points.append((x, y))
    return points


def add_vignette(image: Image.Image, strength: int) -> Image.Image:
    width, height = image.size
    overlay = Image.new("RGB", image.size, BLACK)
    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    margin = min(width, height) // 7
    mask_draw.ellipse(
        (margin, margin, width - margin, height - margin),
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(min(width, height) // 9))
    return Image.composite(image, overlay, Image.eval(mask, lambda p: 255 - p // strength))


def draw_record(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    width = box[2] - box[0]
    outline = max(3, width // 28)
    draw.ellipse(box, fill=BLACK, outline=OFF_WHITE, width=outline)

    for inset, color in (
        (outline * 2, (52, 44, 40)),
        (outline * 6, (74, 66, 60)),
    ):
        draw.ellipse(
            (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset),
            outline=color,
            width=max(2, outline // 2),
        )

    inner = width // 8
    cx = (box[0] + box[2]) // 2
    cy = (box[1] + box[3]) // 2
    draw.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), fill=GOLD)
    draw.ellipse((cx - inner // 4, cy - inner // 4, cx + inner // 4, cy + inner // 4), fill=OFF_WHITE)


def draw_badge(image: Image.Image, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    margin_x = int(width * 0.16)
    margin_y = int(height * 0.14)
    panel = (margin_x, margin_y, width - margin_x, height - margin_y)

    draw.rounded_rectangle(panel, radius=height // 8, fill=PAPER, outline=BLACK, width=max(4, height // 42))
    draw.rounded_rectangle(
        (panel[0] + 16, panel[1] + 16, panel[2] - 16, panel[3] - 16),
        radius=height // 9,
        outline=DARK_GOLD,
        width=max(2, height // 72),
    )

    record_box = (
        panel[0] + int(width * 0.04),
        panel[1] + int(height * 0.14),
        panel[0] + int(width * 0.28),
        panel[1] + int(height * 0.54),
    )
    draw_record(draw, record_box)

    title_font = font(FUTURA, int(height * 0.22))
    subtitle_font = font(FUTURA, int(height * 0.095))
    tag_font = font(ARIAL_BOLD, int(height * 0.07))

    tx = panel[0] + int(width * 0.34)
    ty = panel[1] + int(height * 0.16)
    draw.text((tx, ty), title, font=title_font, fill=WINE)
    draw.text((tx + 4, ty + int(height * 0.19)), subtitle, font=subtitle_font, fill=BLACK)
    draw.text((tx, panel[3] - int(height * 0.16)), "31 FILMS", font=tag_font, fill=TEAL)


def save_icon(back_path: Path, front_path: Path, size: tuple[int, int], seed: int) -> None:
    width, height = size

    back = Image.new("RGB", size, PAPER)
    add_paper_texture(back, seed)
    add_starburst(back, (width // 3, height // 3), seed + 1)
    back = add_vignette(back, 2)
    draw = ImageDraw.Draw(back)

    stripe_width = max(14, width // 18)
    for index in range(-2, 8):
        x = index * stripe_width * 2
        draw.polygon(
            [(x, 0), (x + stripe_width, 0), (x + stripe_width * 3, height), (x + stripe_width * 2, height)],
            fill=(246, 228, 198) if index % 2 == 0 else (214, 184, 142),
        )

    back = add_vignette(back, 2)
    back.save(back_path)

    front = Image.new("RGB", size, PAPER_SHADE)
    add_paper_texture(front, seed + 2)
    draw = ImageDraw.Draw(front)
    draw.rectangle((0, 0, width, height), fill=(0, 0, 0))
    draw.rounded_rectangle((18, 18, width - 18, height - 18), radius=height // 7, fill=PAPER_SHADE)
    add_starburst(front, (width // 2, height // 2), seed + 3)
    draw_badge(front, "ELVIS", "WATCH")
    front = add_vignette(front, 3)
    front.save(front_path)


def draw_poster_card(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int],
    title: str,
) -> None:
    radius = max(16, (box[3] - box[1]) // 18)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=BLACK, width=3)
    draw.rounded_rectangle(
        (box[0] + 10, box[1] + 10, box[2] - 10, box[3] - 10),
        radius=radius - 6,
        outline=OFF_WHITE,
        width=2,
    )

    title_font = font(GILL_SANS, max(24, (box[3] - box[1]) // 11))
    tx = box[0] + 18
    ty = box[1] + 18
    for line in title.split("\n"):
        draw.text((tx, ty), line, font=title_font, fill=OFF_WHITE)
        ty += title_font.size + 4


def save_banner(path: Path, size: tuple[int, int], wide: bool, seed: int) -> None:
    width, height = size
    image = Image.new("RGB", size, PAPER)
    add_paper_texture(image, seed)
    add_starburst(image, (int(width * 0.2), int(height * 0.36)), seed + 1)

    draw = ImageDraw.Draw(image)
    for index in range(-2, 10):
        offset = int(index * width * 0.09)
        draw.polygon(
            [
                (offset, 0),
                (offset + int(width * 0.045), 0),
                (offset + int(width * 0.19), height),
                (offset + int(width * 0.145), height),
            ],
            fill=(239, 218, 182) if index % 2 == 0 else (220, 190, 150),
        )

    draw.rectangle((0, int(height * 0.63), width, height), fill=BLACK)
    draw.text((int(width * 0.055), int(height * 0.11)), "ELVIS WATCH", font=font(FUTURA, int(height * 0.17)), fill=WINE)
    draw.text(
        (int(width * 0.06), int(height * 0.31)),
        "A living-room browser for every Elvis feature film.",
        font=font(GILL_SANS, int(height * 0.06)),
        fill=BLACK,
    )
    draw.text(
        (int(width * 0.06), int(height * 0.70)),
        "LOVE ME TENDER  •  JAILHOUSE ROCK  •  BLUE HAWAII  •  VIVA LAS VEGAS  •  CHANGE OF HABIT",
        font=font(ARIAL_BOLD, int(height * 0.05)),
        fill=OFF_WHITE,
    )

    card_width = int(width * (0.13 if wide else 0.16))
    card_height = int(height * 0.56)
    gap = int(width * 0.016)
    start_x = int(width * (0.56 if wide else 0.54))
    y = int(height * 0.12)
    posters = [
        ("LOVE\nME TENDER", WINE),
        ("KING\nCREOLE", BLUE),
        ("BLUE\nHAWAII", TEAL),
        ("VIVA LAS\nVEGAS", CHERRY),
        ("CHARRO!", (111, 81, 48)),
    ]
    if wide:
        posters.append(("CHANGE OF\nHABIT", (78, 105, 65)))

    for index, (title, color) in enumerate(posters):
        x = start_x + index * (card_width + gap)
        draw_poster_card(draw, (x, y, x + card_width, y + card_height), color, title)

    image = add_vignette(image, 3)
    image.save(path)


def main() -> None:
    save_icon(
        BRAND_ROOT / "App Icon - Small.imagestack/Back.imagestacklayer/Content.imageset/icon-small-back.png",
        BRAND_ROOT / "App Icon - Small.imagestack/Front.imagestacklayer/Content.imageset/icon-small-front.png",
        (400, 240),
        seed=7,
    )
    save_icon(
        BRAND_ROOT / "App Icon - Large.imagestack/Back.imagestacklayer/Content.imageset/icon-large-back.png",
        BRAND_ROOT / "App Icon - Large.imagestack/Front.imagestacklayer/Content.imageset/icon-large-front.png",
        (1280, 768),
        seed=17,
    )
    save_banner(
        BRAND_ROOT / "Top Shelf Image.imageset/top-shelf.png",
        (1920, 720),
        wide=False,
        seed=23,
    )
    save_banner(
        BRAND_ROOT / "Top Shelf Image Wide.imageset/top-shelf-wide.png",
        (2320, 720),
        wide=True,
        seed=29,
    )
    print("Generated Elvis Watch tvOS brand assets.")


if __name__ == "__main__":
    main()
