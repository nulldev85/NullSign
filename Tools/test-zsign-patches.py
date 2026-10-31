#!/usr/bin/env python3
"""Verify clean application, repeat builds, and refusal of unreviewed edits."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("prepare_zsign", ROOT / "Tools/prepare-zsign.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

with tempfile.TemporaryDirectory(prefix="nullsign-patch-tests-") as directory:
    checkout = Path(directory) / "Zsign"
    subprocess.run(["git", "clone", "--quiet", "--shared", "--no-checkout", str(ROOT / "Zsign"), str(checkout)], check=True)
    subprocess.run(["git", "-C", str(checkout), "checkout", "--quiet", "--detach", prepare.BASE], check=True)
    prepare.ZSIGN = checkout
    prepare.prepare()
    prepare.prepare()
    altered = checkout / "src/certificate_validation.h"
    altered.write_text(altered.read_text() + "\n// Unreviewed local edit\n")
    try:
        prepare.prepare()
    except SystemExit as error:
        assert "refusing to build" in str(error), str(error)
    else:
        raise AssertionError("Unreviewed dependency edits were accepted")
    assert altered.read_text().endswith("// Unreviewed local edit\n"), "Local edits were overwritten"
print("Pinned dependency patches passed clean apply, idempotence, and local-edit protection.")
