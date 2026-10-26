"""Derive labeled contact sheets from the complete native nine-preset capture matrix.

Sheets aid visual comparison; source PNGs remain the evidence for fine details.
"""
import hashlib
import io
import json
import pathlib
import re
import sys

from PIL import Image, ImageCms, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWED = ROOT / "docs/roadmap/2026-10-20/implementation"
source = pathlib.Path(sys.argv[1]).resolve(strict=True)
if not source.is_relative_to(ALLOWED) or source == ALLOWED:
    raise ValueError("Only private validation captures allowed")
destination = source.with_name(source.name + "-contacts")
destination.mkdir(exist_ok=True)
presets = ["GitHub Light", "Solarized Light", "GitHub Dark", "Dracula", "Nord",
           "One Dark Pro", "Monokai Pro", "Tokyo Night", "Solarized Dark"]
panes = ["Editor", "Settings-general", "Settings-accounts", "Settings-integrations",
         "Settings-ai", "Settings-git", "Settings-workflows", "Settings-workspace",
         "Settings-shortcuts", "Settings-subscription", "Repository"]
matrix = {}
for test in json.loads((source / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        label = attachment["suggestedHumanReadableName"]
        match = re.match(r"^Visual-Preset-(.+)-(Editor|Settings-[a-z]+|Repository|Conflict-(?:Unresolved|Preview|Analysis))_", label)
        if not match:
            continue
        key = match.groups()
        if key in matrix:
            raise ValueError("Duplicate preset/pane capture")
        matrix[key] = attachment
if any(pane.startswith("Conflict-") for _, pane in matrix):
    panes += ["Conflict-Unresolved", "Conflict-Preview", "Conflict-Analysis"]
expected = {(preset, pane) for preset in presets for pane in panes}
if set(matrix) != expected:
    raise ValueError(f"Incomplete matrix: missing={expected - set(matrix)}, extra={set(matrix) - expected}")
profile = ImageCms.createProfile("sRGB")
manifest, provenance = [], []
for preset in presets:
    sheet = Image.new("RGB", (1800, ((len(panes) + 2) // 3) * 450), "#e4e4e4")
    draw = ImageDraw.Draw(sheet)
    entries = []
    for index, pane in enumerate(panes):
        attachment = matrix[(preset, pane)]
        name = attachment["exportedFileName"]
        if pathlib.Path(name).name != name:
            raise ValueError("Unsafe attachment path")
        file = (source / name).resolve(strict=True)
        if not file.is_relative_to(source):
            raise ValueError("Attachment outside capture directory")
        data = file.read_bytes()
        with Image.open(io.BytesIO(data)) as original:
            if original.format != "PNG":
                raise ValueError("PNG expected")
            rgb = original.convert("RGB")
            if original.info.get("icc_profile"):
                rgb = ImageCms.profileToProfile(rgb, ImageCms.ImageCmsProfile(io.BytesIO(original.info["icc_profile"])), profile, outputMode="RGB")
            rgb.thumbnail((590, 420), Image.Resampling.LANCZOS)
            x, y = (index % 3) * 600, (index // 3) * 450
            draw.text((x + 8, y + 8), f"{preset} | {pane}", fill="black")
            sheet.paste(rgb, (x + 5, y + 26))
            entries.append({"pane": pane, "file": name, "sha256": hashlib.sha256(data).hexdigest(), "originalSize": original.size})
    output = "Visual-Overview-" + preset.replace(" ", "-") + ".png"
    sheet.save(destination / output, icc_profile=ImageCms.ImageCmsProfile(profile).tobytes())
    manifest.append({"testIdentifier": "Derived contact sheet; inspect originals for fine details",
                     "attachments": [{"exportedFileName": output, "suggestedHumanReadableName": output}]})
    provenance.append({"preset": preset, "sheet": output, "sheetSHA256": hashlib.sha256((destination / output).read_bytes()).hexdigest(), "sources": entries})
(destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(destination / "provenance.json").write_text(json.dumps({"sourceDirectory": str(source.relative_to(ROOT)), "derived": True, "notFullResolutionReview": True, "presets": provenance}, indent=2) + "\n")
print(json.dumps({"originals": len(matrix), "contactSheets": len(manifest), "output": str(destination.relative_to(ROOT))}))
