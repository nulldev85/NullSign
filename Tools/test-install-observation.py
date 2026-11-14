#!/usr/bin/env python3
"""Exercise the production completion tracker and Objective-C bridge on macOS."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
groups = [
    ("completion", "Feather/Utilities/InstallCompletionTracker.swift", "Tools/Fixtures/InstallObservationTests.swift"),
    ("runtime", "NimbleKit/Sources/NimbleExtensions/UIApplication/SystemInstallRuntime.swift", "Tools/Fixtures/InstallRuntimeTests.swift"),
    ("download", "Feather/Backend/Observable/Download.swift", "Tools/Fixtures/DownloadProgressTests.swift"),
]
with tempfile.TemporaryDirectory(prefix="nullsign-install-observation-") as directory:
    for optimization in ["-Onone", "-O"]:
        for name, production, fixture in groups:
            executable = Path(directory) / (name + optimization)
            language = "6" if name == "runtime" else "5"
            extra = [str(ROOT / "Feather/Utilities/InstallCompletionTracker.swift")] if name == "runtime" else []
            subprocess.run(["xcrun", "swiftc", "-swift-version", language, optimization,
                            str(ROOT / production), *extra, str(ROOT / fixture), "-o", str(executable)],
                           check=True, timeout=60)
            subprocess.run([str(executable)], check=True, timeout=30)
