#!/usr/bin/env python3
"""Generate framed App Store screenshots using Apple iPhone 17 Pro Max bezels."""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import sys

# Paths
BASE = Path(__file__).parent
SCREENSHOTS = BASE / "screenshots"
BEZELS = BASE / "bezels"
OUTPUT = BASE / "framed"
OUTPUT.mkdir(exist_ok=True)

# Canvas size (App Store 6.9")
W, H = 1320, 2868

# Bezel dimensions
BEZEL_W, BEZEL_H = 1470, 3000
SCREEN_OFFSET_X = 75  # (1470-1320)/2
SCREEN_OFFSET_Y = 66  # (3000-2868)/2

# Colors
ACCENT = (255, 112, 0)  # Mistral Orange #FF7000
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GRAY = (102, 102, 102)
GRAY_DARK = (136, 136, 136)

# Load SF system font with variable font weight support
def load_font(size, weight_name="Regular"):
    font_path = "/System/Library/Fonts/SFNS.ttf"
    try:
        f = ImageFont.truetype(font_path, size)
        f.set_variation_by_name(weight_name)
        return f
    except (OSError, IOError, ValueError):
        return ImageFont.load_default()

FONT_HEADLINE = load_font(82, "Bold")
FONT_SUBTEXT = load_font(44, "Semibold")

# Screenshot definitions
# (output_name, screenshot_file_timestamp, headline_parts, subtext, bg_color, bezel_file)
SHOTS = [
    # Light mode - Silver bezel
    ("01-recording-light", "04.41.59", [("Record", True), (" your thoughts", False)],
     "Capture ideas instantly", "white", "Silver"),
    ("02-list-light", "04.36.13", [("Record", True), (" and ", False), ("transcribe", True)],
     "All your voice memos in one place", "white", "Silver"),
    ("03-transcript-light", "04.36.47", [("Instant ", False), ("AI", True), (" transcription", False)],
     "Powered by Mistral Voxtral", "white", "Silver"),
    ("04-summary-light", "04.37.06", [("Smart ", False), ("summaries", True), (" in one tap", False)],
     "", "white", "Silver"),
    ("05-prompts-light", "04.38.09", [("Custom ", False), ("AI prompts", True)],
     "Summaries, todos, translations and more", "white", "Silver"),
    ("06-menu-light", "04.38.22", [("Transform", True), (" with one tap", False)],
     "", "white", "Silver"),

    # Dark mode - Silver bezel
    ("07-recording-dark", "04.41.46", [("Record", True), (" your thoughts", False)],
     "Capture ideas instantly", "black", "Silver"),
    ("08-list-dark", "04.38.59", [("Record", True), (" and ", False), ("transcribe", True)],
     "All your voice memos in one place", "black", "Silver"),
    ("09-transcript-dark", "04.39.07", [("Instant ", False), ("AI", True), (" transcription", False)],
     "Powered by Mistral Voxtral", "black", "Silver"),
    ("10-summary-dark", "04.39.16", [("Smart ", False), ("summaries", True), (" in one tap", False)],
     "", "black", "Silver"),
    ("11-prompts-dark", "04.39.40", [("Custom ", False), ("AI prompts", True)],
     "Summaries, todos, translations and more", "black", "Silver"),
    ("12-menu-dark", "04.39.24", [("Transform", True), (" with one tap", False)],
     "", "black", "Silver"),
]

DEVICE_SCALE = 0.60
DEVICE_VPOS = 0.52  # Vertical center (slightly above true center to leave room for subtext)


def find_screenshot(timestamp):
    """Find screenshot file by timestamp."""
    for f in SCREENSHOTS.iterdir():
        if timestamp in f.name and f.suffix == ".png":
            return f
    return None


def draw_headline(draw, parts, y, is_white):
    """Draw headline with accent-colored words."""
    normal_color = BLACK if is_white else WHITE

    # Measure total width
    total_w = 0
    for text, _ in parts:
        bbox = draw.textbbox((0, 0), text, font=FONT_HEADLINE)
        total_w += bbox[2] - bbox[0]

    # Draw centered
    x = (W - total_w) // 2
    for text, is_accent in parts:
        color = ACCENT if is_accent else normal_color
        draw.text((x, y), text, font=FONT_HEADLINE, fill=color)
        bbox = draw.textbbox((0, 0), text, font=FONT_HEADLINE)
        x += bbox[2] - bbox[0]


def generate(name, timestamp, headline_parts, subtext, bg, bezel_color):
    """Generate a single framed screenshot."""
    screenshot_path = find_screenshot(timestamp)
    if not screenshot_path:
        print(f"  SKIP {name}: screenshot with timestamp {timestamp} not found")
        return False

    bezel_path = BEZELS / f"iPhone 17 Pro Max - {bezel_color} - Portrait.png"
    if not bezel_path.exists():
        print(f"  SKIP {name}: bezel {bezel_path.name} not found")
        return False

    is_white = bg == "white"
    bg_color = WHITE if is_white else BLACK

    # Create canvas
    canvas = Image.new("RGB", (W, H), bg_color)

    # Load and scale bezel + screenshot
    bezel = Image.open(bezel_path).convert("RGBA")
    screenshot = Image.open(screenshot_path).convert("RGB")

    # Scale
    bezel_draw_w = int(BEZEL_W * DEVICE_SCALE)
    bezel_draw_h = int(BEZEL_H * DEVICE_SCALE)
    screen_draw_w = int(1320 * DEVICE_SCALE)
    screen_draw_h = int(2868 * DEVICE_SCALE)

    bezel_resized = bezel.resize((bezel_draw_w, bezel_draw_h), Image.LANCZOS)
    screenshot_resized = screenshot.resize((screen_draw_w, screen_draw_h), Image.LANCZOS)

    # Position (centered vertically)
    bezel_x = (W - bezel_draw_w) // 2
    bezel_y = int(H * DEVICE_VPOS - bezel_draw_h / 2)
    screen_x = bezel_x + int(SCREEN_OFFSET_X * DEVICE_SCALE)
    screen_y = bezel_y + int(SCREEN_OFFSET_Y * DEVICE_SCALE)

    # Paste screenshot, then bezel on top
    canvas.paste(screenshot_resized, (screen_x, screen_y))

    # Composite bezel (has transparency)
    bezel_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bezel_layer.paste(bezel_resized, (bezel_x, bezel_y))
    canvas = Image.composite(bezel_layer, canvas.convert("RGBA"), bezel_layer).convert("RGB")

    # Draw text
    draw = ImageDraw.Draw(canvas)

    # Headline: centered between top and device top
    headline_bbox = draw.textbbox((0, 0), "Xg", font=FONT_HEADLINE)
    headline_h = headline_bbox[3] - headline_bbox[1]
    headline_y = bezel_y // 2 - headline_h // 2
    draw_headline(draw, headline_parts, headline_y, is_white)

    # Subtext: centered between device bottom and canvas bottom
    if subtext:
        sub_color = GRAY if is_white else GRAY_DARK
        bbox = draw.textbbox((0, 0), subtext, font=FONT_SUBTEXT)
        sub_w = bbox[2] - bbox[0]
        sub_h = bbox[3] - bbox[1]
        device_bottom = bezel_y + bezel_draw_h
        sub_x = (W - sub_w) // 2
        sub_y = device_bottom + (H - device_bottom) // 2 - sub_h // 2
        draw.text((sub_x, sub_y), subtext, font=FONT_SUBTEXT, fill=sub_color)

    # Save
    out_path = OUTPUT / f"{name}.png"
    canvas.save(out_path, "PNG")
    return True


def main():
    print(f"Generating {len(SHOTS)} framed screenshots...")
    print(f"Output: {OUTPUT}")
    print()

    ok = 0
    for shot in SHOTS:
        name = shot[0]
        success = generate(*shot)
        if success:
            ok += 1
            print(f"  OK  {name}.png")

    print(f"\nDone: {ok}/{len(SHOTS)} screenshots generated in {OUTPUT}")


if __name__ == "__main__":
    main()
