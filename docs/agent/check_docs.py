"""Read-only validation of documentation transfer; Python stdlib only.

Checks the installed root AGENTS.md and the lossless thematic transfer.
No network, Flutter, migrations, Git writes or runtime configuration changes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prose(text):
    return re.sub(r"^(`{3,}|~{3,}).*?^\1[^\n]*$", "", text,
                  flags=re.MULTILINE | re.DOTALL)


def anchors(text):
    result = set(re.findall(r'<a\s+(?:id|name)=[\"\']([^\"\']+)', text))
    seen = {}
    for title in re.findall(r"^#{1,6}\s+(.+?)\s*#*\s*$", prose(text), re.MULTILINE):
        title = re.sub(r"[`*_]", "", title).lower()
        slug = re.sub(r"[^\w\- ]", "", title).replace(" ", "-")
        count = seen.get(slug, 0)
        seen[slug] = count + 1
        result.add(slug + (f"-{count}" if count else ""))
    return result


def check():
    manifest = json.loads((ROOT / "docs/agent/source-map.json").read_text())
    source = manifest["source"]
    archive = (ROOT / source["archive"]).read_bytes()
    expected_git = subprocess.check_output(
        ["git", "show", f'{source["git_commit"]}:{source["git_path"]}'], cwd=ROOT)
    require(archive == expected_git, "Archive differs from original Git blob")
    require(digest(archive) == source["sha256"], "Archive SHA256 differs")
    require(len(archive) == source["bytes"], "Archive byte count differs")
    require(len(archive.decode("utf-8")) == source["utf8_chars"], "Character count differs")
    checksum = (ROOT / source["checksum_file"]).read_text()
    require(checksum == f'{source["sha256"]}  AGENTS-4fa4a19.md\n', "Checksum file differs")
    lines = archive.splitlines(keepends=True)
    require(len(lines) == source["lines"] == 526, "Source line count differs")
    coverage = [0] * len(lines)
    ids = set()
    for block in manifest["blocks"]:
        first, last = block["source_start"], block["source_end"]
        require(1 <= first <= last <= len(lines), "Invalid source range")
        require(block["id"] not in ids, "Duplicate source block ID")
        ids.add(block["id"])
        target = ROOT / block["target"]
        require(target.parent == ROOT / "docs/agent" and target.suffix == ".md",
                "Primary target must be thematic documentation, not archive")
        data = target.read_bytes()
        begin = f'<!-- BEGIN {block["id"]} -->\n'.encode()
        end = f'<!-- END {block["id"]} -->'.encode()
        require(data.count(begin) == data.count(end) == 1, "Markers not unique")
        start = data.index(begin) + len(begin)
        stop = data.index(end)
        expected = b"".join(lines[first - 1:last])
        require(data[start:stop] == expected, f"Source block differs: {block['id']}")
        require(digest(expected) == block["sha256"], "Block hash differs")
        require(start == block["target_byte_start"] and stop == block["target_byte_end"],
                "Block byte offsets differ")
        require(data[:start].count(b"\n") + 1 == block["target_start"], "Start line differs")
        require(block["target_end"] == block["target_start"] + last - first,
                "End line differs")
        for index in range(first - 1, last):
            coverage[index] += 1
    require(all(count == 1 for count in coverage), "Each source line must map exactly once")
    print(f"PASS archive: {len(archive)} bytes; SHA256 {digest(archive)}; Git blob identical")
    print(f"PASS thematic coverage: {len(coverage)}/{len(lines)} lines, {len(ids)} exact blocks")

    root_path = ROOT / "AGENTS.md"
    root = root_path.read_text(encoding="utf-8")
    require(len(root) <= 10000, f"Root is {len(root)} characters, exceeds 10000")
    ui = root.split("## UI-contract\n", 1)[1].split("\n## Restricted-features", 1)[0]
    require([int(n) for n in re.findall(r"^(\d+)\.", ui, re.MULTILINE)] == list(range(1, 19)),
            "UI rules must be exactly numbered 1 through 18")
    for term in ("read-only", "plan-only", "worktree", "force push", "repo settings",
                 "deploy", "live", "НИКОГДА", "каждого"):
        # Analyze phrasing is case insensitive; other safety markers are literal.
        if term == "каждого":
            require("каждого" in root.lower(), "Analyze before every commit missing")
        else:
            require(term in root, f"Missing permission marker: {term}")
    require("Ты уже знаешь всё" not in root, "Obsolete preload instruction in root")
    permissions = root.split("## Permissions\n", 1)[1].split("\n## Engineering", 1)[0]
    allowed, restricted = permissions.split("- Только по отдельной прямой команде:", 1)
    for term in ("feature-ветка", "тесты", "commit", "push feature-ветки", "создание PR"):
        require(term in allowed, f"Missing autonomous action: {term}")
    for term in ("push в main", "merge", "force push", "deploy", "live миграций",
                 "secrets", "repo settings"):
        require(term in restricted, f"Missing explicit approval boundary: {term}")
    require("push-уведомления" in root, "Push notifications must not prohibit feature push")
    require("порог >6 файлов НЕ требует" in root, "Superseded file threshold not explicit")
    for term in ("ConfirmDialog", "trim", "tombstone", "#22D3EE", "#0E7490",
                 "Theme(data:", "initialProgramId/initialProgramIds", "notDone"):
        require(term in root, f"Missing invariant/exception marker: {term}")
    print(f"PASS root: {len(root)} UTF-8 characters; 18 UI rules")

    brief_original = subprocess.check_output(
        ["git", "show", f'{source["git_commit"]}:docs/design-brief.md'], cwd=ROOT)
    brief = (ROOT / "docs/design-brief.md").read_bytes()
    marker = "## Дизайн-бриф".encode()
    require(brief_original[brief_original.index(marker):] == brief[brief.index(marker):],
            "Historical design brief body was changed")
    print("PASS historical design brief body: byte-identical")

    documents = [root_path, ROOT / "README.md", ROOT / "docs/design-brief.md"]
    documents += sorted((ROOT / "docs/agent").glob("*.md"))

    links = 0
    for document in documents:
        text = root if document == root_path else document.read_text()
        for raw in re.findall(r"\[[^\]]*\]\(([^)]+)\)", prose(text)):
            uri = raw.strip().split()[0].strip("<>")
            parts = urlsplit(uri)
            if parts.scheme or parts.netloc:
                continue
            target = (document.parent / unquote(parts.path)).resolve() if parts.path else document
            require(target.is_relative_to(ROOT), f"Link outside repo: {uri}")
            require(target.exists(), f"Missing target in {document.relative_to(ROOT)}: {uri}")
            if parts.fragment:
                target_text = root if target == root_path else target.read_text()
                require(unquote(parts.fragment) in anchors(target_text),
                        f"Missing anchor in {document.relative_to(ROOT)}: {uri}")
            links += 1
    print(f"PASS local links/anchors: {links} across {len(documents)} documents (no HTTP check)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    try:
        check()
    except (ValueError, KeyError, IndexError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"FAIL: {error}\n")
