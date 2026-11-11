#!/usr/bin/env python3
"""Exercise production silent audio through Apple's real macOS decoder/player."""
from pathlib import Path
import platform
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nullsign-background-audio-") as directory:
    executable = Path(directory) / "background-audio-tests"
    subprocess.run([
        "xcrun", "swiftc", "-swift-version", "5",
        "-target", f"{platform.machine()}-apple-macosx12.0",
        str(ROOT / "Feather/Utilities/SilentAudio.swift"),
        str(ROOT / "Feather/Utilities/BackgroundAudioManager.swift"),
        str(ROOT / "Tools/Fixtures/BackgroundAudioTests.swift"),
        "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable)], check=True, timeout=30)
