"""Check literal system image names against AppKit on this Mac, preserving locations.

This inventory cannot certify older OS availability or dynamically built names.
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
negative = "--missing-symbol-control" in sys.argv
OUTPUT = ROOT / ("docs/roadmap/2026-10-20/implementation/sf-symbols-negative-control.json" if negative
                 else "docs/roadmap/2026-10-20/implementation/sf-symbols-current.json")
references = []
for name in subprocess.check_output(["rg", "--files", "GitMac", "-g", "*.swift"], cwd=ROOT, text=True).splitlines():
    text = (ROOT / name).read_text()
    for match in re.finditer(r'\b(?:systemName|systemImage|iconName)\s*:\s*"([^"\n]+)"', text):
        symbol = match[1]
        if "\\(" in symbol or "\\" in symbol:
            continue
        references.append({"file": name, "line": text.count("\n", 0, match.start()) + 1, "symbol": symbol})
symbols = sorted({item["symbol"] for item in references})
if negative:
    symbols.append("gitmac.deliberately.unavailable.symbol")
with tempfile.TemporaryDirectory(prefix="gitmac-symbol-audit-") as directory:
    folder = pathlib.Path(directory)
    names = folder / "names.json"
    names.write_text(json.dumps(symbols))
    source = folder / "GitMacSymbolInventory.swift"
    source.write_text('''import AppKit
import Foundation
let names = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var invalid: [String] = []
for name in names {
    if NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil { invalid.append(name) }
}
FileHandle.standardOutput.write(try JSONEncoder().encode(invalid))
''')
    invalid = json.loads(subprocess.check_output(["/usr/bin/xcrun", "swift", str(source), str(names)], text=True, timeout=90))
findings = [item for item in references if item["symbol"] in invalid]
report = {"date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "scope": "Literal systemName/systemImage/iconName arguments under GitMac; current OS only",
          "uniqueSymbols": len(symbols), "references": len(references), "invalidSymbols": invalid,
          "findings": findings, "allButtonsFunctionallyCertified": False, "negativeControl": negative,
          "limits": ["Dynamic names, model icon string properties and custom wrappers are not exhaustively resolved.",
                     "A valid symbol does not prove action wiring, hit target, contrast or minimum supported OS availability."]}
OUTPUT.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if invalid:
    raise SystemExit(1)
