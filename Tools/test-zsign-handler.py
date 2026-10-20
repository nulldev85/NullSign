#!/usr/bin/env python3
"""Compile the real Swift app handler against a controlled engine boundary."""

from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nullsign-handler-tests-") as directory:
    work = Path(directory)
    subprocess.run([
        "xcrun", "swiftc", "-emit-module", "-emit-library", "-module-name", "ZsignSwift",
        str(ROOT / "Tools/Fixtures/ZsignStub.swift"),
        "-emit-module-path", str(work / "ZsignSwift.swiftmodule"),
        "-o", str(work / "libZsignSwift.dylib"),
    ], check=True)
    subprocess.run([
        "xcrun", "swiftc", "-I", str(work), "-L", str(work), "-lZsignSwift",
        "-Xlinker", "-rpath", "-Xlinker", str(work),
        str(ROOT / "Feather/Utilities/Handlers/ZsignHandler.swift"),
        str(ROOT / "Tools/Fixtures/ZsignHandlerTests.swift"),
        "-o", str(work / "handler-tests"),
    ], check=True)
    subprocess.run([str(work / "handler-tests")], check=True)
