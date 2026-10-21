#!/usr/bin/env python3
"""Apply Zsign 1.1.3's resource fix to the pinned Swift-compatible fork.

Upstream: zhlynn/zsign@9299685bab7ef99827e06e5dfda93af747386590 (#413).
Keep the iOS/Swift adapter and dependency pin; do not switch to the CLI package.
"""

from pathlib import Path
import hashlib
import json
import subprocess


ROOT = Path(__file__).resolve().parents[1]
ZSIGN = ROOT / "Zsign"
BASE = "6ffe703df73ef9069adacdbb19d571f11a69a801"
PATCH = ROOT / "Tools/patches/zsign-1.1.3-unreadable-resources.patch"


def git(*args):
    return subprocess.run(
        ["git", "-C", str(ZSIGN), *args], capture_output=True, text=True, check=False
    )


def prepare():
    revision = git("rev-parse", "HEAD")
    if revision.returncode or revision.stdout.strip() != BASE:
        raise SystemExit("Unsupported Zsign checkout; initialize the pinned submodule before building.")

    # Verify the entire patched files, not just hunk context. Unrecognized local
    # changes must never be silently overwritten or accepted as the reviewed fix.
    names = ("src/bundle.cpp", "src/common/sha.cpp")
    actual = {name: (ZSIGN / name).read_bytes().replace(b"\r\n", b"\n") for name in names}
    original = {}
    for name in names:
        result = subprocess.run(
            ["git", "-C", str(ZSIGN), "show", f"{BASE}:{name}"], capture_output=True, check=True
        )
        original[name] = result.stdout.replace(b"\r\n", b"\n")

    # git apply also handles the already-applied case, so repeated make/Xcode
    # builds are safe. Check first to avoid partially applying a dependency fix.
    forward = git("apply", "--ignore-space-change", "--check", str(PATCH))
    if forward.returncode == 0:
        if actual != original:
            raise SystemExit("Zsign source has unexpected edits; refusing to apply the patch.")
        git_result = git("apply", "--ignore-space-change", str(PATCH))
        if git_result.returncode:
            raise SystemExit(git_result.stderr)
        print("Applied Zsign 1.1.3 unreadable-resource fix to the pinned iOS package.")
    else:
        # Accept only the complete reviewed result, including the already-applied case.
        expected = json.loads(PATCH.with_suffix(".json").read_text())
        if any(hashlib.sha256(actual[name]).hexdigest() != expected[name] for name in names):
            raise SystemExit("Zsign patch does not match the reviewed source; refusing to build.")
        print("Zsign unreadable-resource fix is already applied.")


if __name__ == "__main__":
    prepare()
