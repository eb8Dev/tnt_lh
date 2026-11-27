"""Frames the raw app screens (store/raw, rendered by
test/store/store_screens_test.dart) into store listing screenshots.

  python3 tool/store/frame.py

Writes:
  store/appstore/6.9in/NN.png   1320 x 2868  (App Store, iPhone 6.9")
  store/appstore/6.5in/NN.png   1284 x 2778  (App Store, iPhone 6.5")
  store/playstore/phone/NN.png  1080 x 1920  (Google Play phone)
and copies them into the fastlane folders both stores upload from.
"""
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "store" / "raw"
FONTS = ROOT / "google_fonts"

# Each shop's own colours: the cafe's greens, the bakery's chocolate and rust.
CAFE = ((60, 92, 42), (24, 48, 22), (150, 190, 110))
BAKERY = ((120, 46, 14), (58, 22, 6), (230, 140, 90))

# Order shown in the stores, with the headline, one supporting line, and whose colours.
SHOTS = [
    ("01_cafe", "Your cafe and bakery,\nin one app", "Teas N Trees and Cream N Crust, Guntur", CAFE),
    ("02_bakery", "Cakes and bakes,\ndelivered", "Cream N Crust, from the oven to your door", BAKERY),
    ("03_filter", "Veg, egg or chicken,\nyou choose", "Filter the menu and sort it by price", BAKERY),
    ("04_item", "Cold coffee,\nmade your way", "Notes for the kitchen on every item", CAFE),
    ("05_bag", "One bag,\nto your door", "Delivery notes, coupons, pay on delivery", CAFE),
    ("00_welcome", "Garden brews\nand fresh bakes", "Sign in with your phone or Google", CAFE),
]


def font(size, weight="ExtraBold"):
    return ImageFont.truetype(str(FONTS / f"Poppins-{weight}.ttf"), size)


def gradient(w, h, colours):
    top, bottom, glow = colours
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    # A soft light bloom top-right, for depth.
    bloom = Image.new("L", (w, h), 0)
    ImageDraw.Draw(bloom).ellipse([w * 0.35, -h * 0.25, w * 1.5, h * 0.35], fill=60)
    bloom = bloom.filter(ImageFilter.GaussianBlur(w * 0.12))
    img.paste(Image.new("RGB", (w, h), glow), (0, 0), bloom)
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def frame(raw, title, sub, colours, w, h):
    canvas = gradient(w, h, colours).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    s = w / 1320  # everything scales off the 6.9" layout

    top = int(150 * s * (h / w) / (2868 / 1320))
    tf = font(int(100 * s))
    sf = font(int(44 * s), "Medium")
    y = top
    for line in title.split("\n"):
        tw = d.textlength(line, font=tf)
        d.text(((w - tw) / 2, y), line, font=tf, fill="white")
        y += int(122 * s)
    y += int(18 * s)
    tw = d.textlength(sub, font=sf)
    d.text(((w - tw) / 2, y), sub, font=sf, fill=(240, 236, 228))
    y += int(110 * s)

    # The screen, in a dark bezel, rising off the bottom edge.
    avail_h = h - y + int(260 * s)
    scr_w = int(w * 0.78)
    scr_h = int(scr_w * raw.height / raw.width)
    if scr_h > avail_h * 1.15:
        scr_h = int(avail_h * 1.15)
        scr_w = int(scr_h * raw.width / raw.height)
    screen = raw.convert("RGB").resize((scr_w, scr_h), Image.LANCZOS)
    radius = int(scr_w * 0.11)
    bezel = int(scr_w * 0.028)
    bw, bh = scr_w + bezel * 2, scr_h + bezel * 2
    x0 = (w - bw) // 2
    y0 = y

    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x0, y0 + int(30 * s), x0 + bw, y0 + bh + int(30 * s)], radius + bezel, fill=(10, 8, 4, 150)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(40 * s)))
    canvas.alpha_composite(shadow)

    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, bw - 1, bh - 1], radius + bezel, fill=(24, 22, 20, 255))
    body.alpha_composite(rounded(screen, radius), (bezel, bezel))
    canvas.alpha_composite(body, (x0, y0))
    return canvas.convert("RGB")  # no alpha: Apple rejects screenshots with it


def main():
    targets = {
        ROOT / "store" / "appstore" / "6.9in": (1320, 2868),
        ROOT / "store" / "appstore" / "6.5in": (1284, 2778),
        ROOT / "store" / "playstore" / "phone": (1080, 1920),
    }
    for out, (w, h) in targets.items():
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        for i, (name, title, sub, colours) in enumerate(SHOTS, 1):
            raw = Image.open(RAW / f"{name}.png")
            frame(raw, title, sub, colours, w, h).save(out / f"{i:02d}_{name[3:]}.png", optimize=True)

    # Into fastlane's folders. iPad shots in the App Store folder are kept.
    ios = ROOT / "ios" / "fastlane" / "screenshots" / "en-US"
    for f in ios.glob("0*.png"):
        f.unlink()
    for f in sorted((ROOT / "store" / "appstore" / "6.9in").glob("*.png")):
        shutil.copy(f, ios / f.name)
    play = ROOT / "android" / "fastlane" / "metadata" / "android" / "en-US" / "images" / "phoneScreenshots"
    shutil.rmtree(play, ignore_errors=True)
    play.mkdir(parents=True)
    for i, f in enumerate(sorted((ROOT / "store" / "playstore" / "phone").glob("*.png")), 1):
        shutil.copy(f, play / f"{i}_en-US.png")
    print("done")


if __name__ == "__main__":
    main()
