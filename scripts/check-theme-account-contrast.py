"""Check rendered account-button glyph colors in original, ICC-correct screenshots.

This checks one consumer that can override DSButton's semantic foreground.
It is not an accessibility certification of arbitrary labels or all interfaces.
"""
import io
import json
import pathlib
import re
import sys

from PIL import Image, ImageChops, ImageCms

root = pathlib.Path(__file__).resolve().parent.parent
directory = pathlib.Path(sys.argv[1]).resolve(strict=True)
allowed = root / "docs/roadmap/2026-10-20/implementation"
if not directory.is_relative_to(allowed) or directory == allowed:
    raise ValueError("Private validation captures required")
source = (root / "GitMac/UI/Theme/ThemeManager.swift").read_text().split("struct ThemePalette: Identifiable {")[1]
accents = dict(re.findall(r'name: "([^"]+)"[\s\S]*?accent: CodableColor\(hex: "#([a-fA-F0-9]{6})"\)', source))
if len(accents) != 9:
    raise ValueError("Expected nine real preset accents")
results = []
for test in json.loads((directory / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        match = re.match(r"^Visual-Preset-(.+)-Settings-accounts_", attachment["suggestedHumanReadableName"])
        if not match:
            continue
        preset = match[1]
        filename = attachment["exportedFileName"]
        if pathlib.Path(filename).name != filename:
            raise ValueError("Unsafe attachment path")
        path = (directory / filename).resolve(strict=True)
        if not path.is_relative_to(directory):
            raise ValueError("Attachment outside capture directory")
        with Image.open(path) as original:
            image = original.convert("RGB")
            if original.info.get("icc_profile"):
                image = ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(io.BytesIO(original.info["icc_profile"])), ImageCms.createProfile("sRGB"), outputMode="RGB")
        accent = tuple(bytes.fromhex(accents[preset]))
        difference = ImageChops.difference(image, Image.new("RGB", image.size, accent))
        red, green, blue = difference.split()
        mask = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda value: 255 if value <= 4 else 0)
        data, rows = mask.tobytes(), []
        # The sign-in button is the only wide, solid accent surface in this pane.
        for y in range(image.height):
            for segment in re.finditer(b"\xff{400,}", data[y * image.width:(y + 1) * image.width]):
                rows.append((y, segment.start(), segment.end()))
        if not rows:
            raise ValueError(f"Cannot locate the account button for {preset}")
        top, bottom = min(row[0] for row in rows), max(row[0] for row in rows)
        left, right = min(row[1] for row in rows), max(row[2] for row in rows)
        center = (left + right) // 2
        glyphs = list(image.crop((center - 160, top + 3, center + 160, bottom - 2)).getdata())
        dark = sum(max(pixel) < 80 for pixel in glyphs)
        light = sum(min(pixel) > 200 for pixel in glyphs)
        linear = [value / 255 / 12.92 if value / 255 <= 0.04045 else ((value / 255 + 0.055) / 1.055) ** 2.4 for value in accent]
        luminance = sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))
        expected = "dark" if (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05) else "light"
        expected_count, other_count = (dark, light) if expected == "dark" else (light, dark)
        passed = expected_count >= 30 and expected_count > other_count * 3
        results.append({"preset": preset, "file": filename, "expectedForeground": expected,
                        "darkGlyphPixels": dark, "lightGlyphPixels": light, "passed": passed})
if len(results) != 9 or len({result["preset"] for result in results}) != 9:
    raise ValueError("Nine unique account screenshots required")
report = {"scope": "Rendered sign-in label plus icon only; normal state", "results": results,
          "checks": len(results), "failures": sum(not result["passed"] for result in results)}
(directory / "account-contrast.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
sys.exit(1 if report["failures"] else 0)
