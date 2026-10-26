"""Read-only source mapping. Syntax edges and inferred targets are separate.

Run with the Python interpreter of the installed graphify environment.
Generated output never replaces graphify-out or .codegraph.
"""
import csv
import argparse
import hashlib
import json
import re
import sqlite3
import subprocess
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_swift

ROOT = Path(__file__).resolve().parents[4]
arguments = argparse.ArgumentParser(description=__doc__)
arguments.add_argument("--output", type=Path, default=ROOT / "docs/roadmap/2026-10-20/mapping")
OUT = arguments.parse_args().output.resolve()
OUT.mkdir(parents=True, exist_ok=True)
parser = Parser(Language(tree_sitter_swift.language()))
tracked = set(subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0"))
found = subprocess.check_output(["rg", "--files", "--hidden", "GitMac", "Tests", "GitMacUITests"], cwd=ROOT).decode().splitlines()
sources = sorted({p for p in found if Path(p).suffix in {".swift", ".h", ".m"}} | {"Package.swift"})
configs = sorted({p for p in tracked if p and (p in {"project.yml", "GitMac.xcodeproj/project.pbxproj"}
    or p.startswith(".github/workflows/") and p.endswith((".yml", ".yaml")))})
configs = sorted(set(configs) | set(subprocess.check_output(["rg", "--files", "scripts"], cwd=ROOT).decode().splitlines()))
files, nodes, calls, references, imports, events = [], [], [], [], [], []
symbols_by_name = defaultdict(list)
type_by_name = defaultdict(list)
trees, blobs = {}, {}
DECLS = {"class_declaration", "protocol_declaration", "extension_declaration", "enum_declaration",
    "function_declaration", "init_declaration", "deinit_declaration", "property_declaration",
    "typealias_declaration", "subscript_declaration"}
TYPES = {"class", "struct", "actor", "enum", "protocol", "extension"}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def save(name, value):
    # Compact large machine indexes; CSVs and coverage remain easy to inspect.
    options = {"indent": 2} if name == "coverage.json" else {"separators": (",", ":")}
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, **options) + "\n")

def table(name, rows, fields):
    with (OUT / name).open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: json.dumps(row.get(k), ensure_ascii=False) if isinstance(row.get(k), (dict, list)) else row.get(k) for k in fields})

def snippet(node, data):
    return data[node.start_byte:node.end_byte].decode("utf-8", "replace")

def location(node):
    return {"startLine": node.start_point.row + 1, "endLine": node.end_point.row + 1}

def child_name(node, data):
    name = node.child_by_field_name("name")
    if name:
        text = snippet(name, data)
        if re.fullmatch(r"[\w`]+", text):
            return text.strip("`")
        bound = name.child_by_field_name("bound_identifier")
        if bound:
            return snippet(bound, data)
        ids = [c for c in name.named_children if c.type in {"simple_identifier", "type_identifier"}]
        if ids:
            return snippet(ids[0], data)
    for value in node.named_children:
        if value.type in {"simple_identifier", "type_identifier"}:
            return snippet(value, data)
    return {"init_declaration": "init", "deinit_declaration": "deinit", "subscript_declaration": "subscript"}.get(node.type)

for file in sources + configs:
    data = (ROOT / file).read_bytes()
    blobs[file] = data
    lines = data.decode("utf-8", "replace").splitlines()
    entry = {"path": file, "tracked": file in tracked, "bytes": len(data), "lines": len(lines), "sha256": digest(data),
        "language": "swift" if file.endswith(".swift") else Path(file).suffix.lstrip("."), "parseStatus": "not-swift"}
    files.append(entry)
    if not file.endswith(".swift"):
        continue
    tree = parser.parse(data)
    trees[file] = tree
    parse_errors = []

    def walk(node, owner=None, enclosing_type=None):
        if node.type == "ERROR" or node.is_missing:
            parse_errors.append({"kind": node.type, **location(node)})
        symbol = None
        if node.type in DECLS:
            is_local_property = node.type == "property_declaration" and owner and owner["kind"] not in TYPES
            name = child_name(node, data)
            if name and not is_local_property:
                kind = node.type.removesuffix("_declaration")
                if node.type == "class_declaration":
                    header = snippet(node, data)[:400]
                    match = re.search(r"\b(class|struct|actor|enum|extension)\b", header)
                    kind = match[1] if match else kind
                body = node.child_by_field_name("body")
                signature = data[node.start_byte:body.start_byte].decode("utf-8", "replace") if body else snippet(node, data).split("\n")[0]
                symbol = {"id": f"{file}:{node.start_byte}", "file": file, "name": name, "kind": kind,
                    "owner": owner["id"] if owner else None, "typeOwner": enclosing_type,
                    "qualifiedName": (owner["qualifiedName"] + "." if owner else "") + name,
                    "signature": signature.strip()[:1000], "evidence": "EXTRACTED_SYNTAX", **location(node)}
                nodes.append(symbol)
                symbols_by_name[name].append(symbol)
                if kind in TYPES:
                    type_by_name[name].append(symbol)
                    enclosing_type = symbol["id"]
        scope = symbol or owner
        if node.type == "import_declaration":
            imports.append({"file": file, "module": re.sub(r"^.*?\bimport\s+", "", snippet(node, data)).strip(), **location(node)})
        if node.type == "type_identifier":
            name = snippet(node, data)
            references.append({"file": file, "name": name, "source": scope["id"] if scope else None, **location(node)})
        if node.type == "call_expression" and node.named_children:
            callee = node.named_children[0]
            target = callee
            if callee.type == "navigation_expression":
                suffix = callee.child_by_field_name("suffix")
                if suffix:
                    target = suffix
                    while target.named_children:
                        target = target.named_children[-1]
            name = snippet(target, data).strip("`")
            if re.fullmatch(r"[\w]+", name):
                full = snippet(callee, data)
                calls.append({"file": file, "source": scope["id"] if scope else None, "name": name,
                    "callee": full if len(full) <= 200 else "…" + full[-199:], "evidence": "EXTRACTED_CALL_SYNTAX", **location(target)})
        for child in node.named_children:
            walk(child, scope, enclosing_type)

    walk(tree.root_node)
    entry["parseStatus"] = "has-errors" if tree.root_node.has_error else "ok"
    entry["parseErrors"] = parse_errors
    # Explicit NotificationCenter channels; dynamic names/observers remain unresolved.
    text = data.decode("utf-8", "replace")
    patterns = [("publish", r"NotificationCenter\.default\.post\s*\(\s*name:\s*\.([A-Za-z_]\w*)"),
        ("subscribe", r"NotificationCenter\.default\.publisher\s*\(\s*for:\s*\.([A-Za-z_]\w*)"),
        ("declare", r"static\s+let\s+(\w+)\s*=\s*Notification\.Name\(\"([^\"]+)\"\)")]
    file_nodes = [n for n in nodes if n["file"] == file]
    for role, pattern in patterns:
        for match in re.finditer(pattern, text, re.S):
            byte = len(text[:match.start()].encode())
            leaf = tree.root_node.descendant_for_byte_range(byte, byte + 1)
            if "comment" in leaf.type or "string" in leaf.type:
                continue
            line = text.count("\n", 0, match.start()) + 1
            owners = [n for n in file_nodes if n["startLine"] <= line <= n["endLine"]]
            owner = min(owners, key=lambda n: n["endLine"] - n["startLine"]) if owners else None
            events.append({"file": file, "line": line, "endLine": text.count("\n", 0, match.end()) + 1,
                "name": match[1], "role": role, "owner": owner["id"] if owner else None,
                "rawValue": match[2] if role == "declare" else None, "evidence": "EXPLICIT_CHANNEL_SYNTAX"})

edges = []
for node in nodes:
    edges.append({"source": "file:" + node["file"] if not node["owner"] else node["owner"], "target": node["id"],
        "kind": "contains", "evidence": "EXTRACTED_SYNTAX", "file": node["file"], "line": node["startLine"]})
for call in calls:
    candidates = [n for n in symbols_by_name.get(call["name"], []) if n["kind"] in TYPES | {"function", "init", "subscript"}]
    call["candidates"] = [n["id"] for n in candidates]
    call["resolution"] = "NO_PROJECT_CANDIDATE" if not candidates else "UNIQUE_NAME_CANDIDATE" if len(candidates) == 1 else "AMBIGUOUS"
    # Name equality is not compiler-proven dispatch, even for a single candidate.
    for candidate in candidates:
        edges.append({"source": call["source"] or "file:" + call["file"], "target": candidate["id"], "kind": "call_candidate",
            "evidence": call["resolution"], "file": call["file"], "line": call["startLine"]})
for ref in references:
    candidates = type_by_name.get(ref["name"], [])
    # Remove the declaration's own identifier occurrence, without guessing scopes.
    candidates = [n for n in candidates if not (n["file"] == ref["file"] and n["startLine"] == ref["startLine"] and n["id"] == ref["source"])]
    ref["candidates"] = [n["id"] for n in candidates]
    ref["resolution"] = "NO_PROJECT_CANDIDATE" if not candidates else "UNIQUE_NAME_CANDIDATE" if len(candidates) == 1 else "AMBIGUOUS"
    for candidate in candidates:
        edges.append({"source": ref["source"] or "file:" + ref["file"], "target": candidate["id"], "kind": "type_candidate",
            "evidence": ref["resolution"], "file": ref["file"], "line": ref["startLine"]})

channels = []
for name in sorted({e["name"] for e in events}):
    rows = [e for e in events if e["name"] == name]
    channels.append({"name": name, "publishers": [e for e in rows if e["role"] == "publish"],
        "subscribers": [e for e in rows if e["role"] == "subscribe"], "declarations": [e for e in rows if e["role"] == "declare"],
        "limit": "Explicit syntax only; dynamic aliases, addObserver and runtime dispatch are not resolved."})

index = {n["id"]: n for n in nodes}
file_edges = Counter()
for edge in edges:
    if edge["kind"] == "contains":
        continue
    target = index[edge["target"]]["file"]
    if target != edge["file"]:
        file_edges[(edge["file"], target, edge["evidence"])] += 1
dependencies = [{"source": a, "target": b, "evidence": confidence, "occurrences": count} for (a, b, confidence), count in sorted(file_edges.items())]
swift = [f for f in files if f["language"] == "swift"]
codegraph = {"indexedFiles": 0, "currentSourceFilesPresent": 0}
db = ROOT / ".codegraph/codegraph.db"
if db.exists():
    connection = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    paths = {r[0] for r in connection.execute("select path from files")}
    codegraph = {"indexedFiles": len(paths), "currentSourceFilesPresent": sum(f["path"] in paths for f in swift)}
    connection.close()
old = json.loads((ROOT / "graphify-out/manifest.json").read_text())
previous = {"manifestFiles": len(old), "currentSwiftPathsPresent": sum(f["path"] in old for f in swift),
    "limit": "Path overlap is not semantic freshness; existing graph left unchanged."}
report = {"date": datetime.now(timezone.utc).isoformat(), "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
    "scope": "Existing non-ignored first-party Swift/C/ObjC files under GitMac, Tests, GitMacUITests, plus Package.swift, build/test scripts and tracked build/CI configs.",
    "exclusions": "Ignored files, dependencies, frameworks, backups and generated audit tools are excluded. Build-target membership is not certified.",
    "files": len(files), "swiftFiles": len(swift), "parsedSwiftFiles": len(trees), "swiftFilesWithSyntaxErrors": sum(f["parseStatus"] == "has-errors" for f in swift),
    "symbols": len(nodes), "calls": len(calls), "typeReferences": len(references), "edges": len(edges),
    "resolutionCounts": dict(Counter(c["resolution"] for c in calls)), "notificationChannels": len(channels),
    "priorCodegraph": codegraph, "priorGraphify": previous,
    "tokenCost": {"deterministicMappingLLMTokens": 0, "hostReviewTokens": "not measured here"},
    "limits": ["Not a compiler-resolved call graph. Candidate edges never prove runtime dispatch.",
        "Parser errors are retained with ranges; syntax coverage is not semantic audit coverage.",
        "A notification without an explicit subscriber is a review candidate, not proof of a dead runtime action."]}
save("source-graph.json", {"report": report, "files": files, "nodes": nodes, "edges": edges})
save("calls.json", calls)
save("type-references.json", references)
save("notifications.json", channels)
save("imports.json", imports)
save("file-dependencies.json", dependencies)
save("coverage.json", report)
table("files.csv", files, ["path", "tracked", "language", "lines", "bytes", "sha256", "parseStatus", "parseErrors"])
table("symbols.csv", nodes, ["file", "startLine", "endLine", "kind", "qualifiedName", "signature", "id", "owner", "evidence"])
table("notifications.csv", events, ["name", "role", "file", "line", "endLine", "owner", "rawValue", "evidence"])
print(json.dumps(report, ensure_ascii=False, indent=2))
