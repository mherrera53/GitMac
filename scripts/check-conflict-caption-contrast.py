"""Rendered advisory-caption regression in fixed native conflict-analysis sheets.

The ROI is intentionally narrow and applies only to this capture fixture, not
arbitrary windows or an accessibility certification of the whole application.
"""
import collections
import io
import json
import pathlib
import sys
from PIL import Image, ImageCms

root = pathlib.Path(__file__).resolve().parent.parent
folder = pathlib.Path(sys.argv[1]).resolve(strict=True)
allowed = root / "docs/roadmap/2026-10-20/implementation"
if not folder.is_relative_to(allowed) or folder == allowed:
    raise ValueError("Private validation captures required")
expected = {"GitHub Light", "Solarized Light", "GitHub Dark", "Dracula", "Nord", "One Dark Pro", "Monokai Pro", "Tokyo Night", "Solarized Dark"}
def luminance(rgb):
    values = [v / 255 for v in rgb]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]
    return sum(v * weight for v, weight in zip(linear, [0.2126, 0.7152, 0.0722]))
def contrast(a, b):
    high, low = sorted([luminance(a), luminance(b)], reverse=True)
    return (high + 0.05) / (low + 0.05)
results = []
for test in json.loads((folder / "manifest.json").read_text()):
    for item in test["attachments"]:
        label = item["suggestedHumanReadableName"]
        if not label.startswith("Visual-Preset-") or "-Conflict-Analysis_" not in label:
            continue
        preset = label[len("Visual-Preset-"):].split("-Conflict-Analysis_")[0]
        name = item["exportedFileName"]
        if pathlib.Path(name).name != name:
            raise ValueError("Unsafe attachment path")
        with Image.open(folder / name) as source:
            image = source.convert("RGB")
            if source.info.get("icc_profile"):
                image = ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(io.BytesIO(source.info["icc_profile"])), ImageCms.createProfile("sRGB"), outputMode="RGB")
            width, height = image.size
            background = image.getpixel((int(width * 0.1), int(height * 0.73)))
            roi = image.crop((int(width * 0.20), int(height * 0.71), int(width * 0.80), int(height * 0.76)))
            colors = collections.Counter(roi.getdata())
            candidates = [(contrast(rgb, background), count, rgb) for rgb, count in colors.items() if count >= 3 and contrast(rgb, background) >= 1.2]
            if not candidates:
                raise ValueError("No caption glyphs in expected native fixture region")
            ratio, count, foreground = max(candidates)
            results.append({"preset": preset, "file": name, "background": background, "foreground": foreground,
                            "contrast": round(ratio, 3), "glyphCorePixels": count, "passed": ratio >= 4.5})
if {r["preset"] for r in results} != expected or len(results) != 9:
    raise ValueError("Exactly nine conflict-analysis presets are required")
report = {"scope": "Caption glyph-core contrast in the captured 600x360-point native analysis fixture; not whole UI approval", "checks": len(results), "failures": sum(not r["passed"] for r in results), "results": results}
print(json.dumps(report, indent=2))
if report["failures"]:
    raise SystemExit(1)
