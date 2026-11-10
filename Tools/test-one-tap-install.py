#!/usr/bin/env python3
"""Run production install preparation and URL/progress helpers at a controlled signing boundary."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nullsign-one-tap-tests-") as directory:
    executable = Path(directory) / "one-tap-install-tests"
    subprocess.run([
        "xcrun", "swiftc", "-swift-version", "5",
        str(ROOT / "Feather/Utilities/AppSigningStage.swift"),
        str(ROOT / "Feather/Utilities/InstallHandoff.swift"),
        str(ROOT / "Feather/Backend/Observable/AppInstallPreparation.swift"),
        str(ROOT / "Tools/Fixtures/OneTapInstallTests.swift"),
        "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable)], check=True)
    work = Path(directory)
    subprocess.run([
        "xcrun", "swiftc", "-emit-module", "-emit-library", "-module-name", "IDeviceSwift",
        str(ROOT / "Tools/Fixtures/InstallerStatusStub.swift"),
        "-emit-module-path", str(work / "IDeviceSwift.swiftmodule"),
        "-o", str(work / "libIDeviceSwift.dylib"),
    ], check=True)
    status_executable = work / "install-status-tests"
    subprocess.run([
        "xcrun", "swiftc", "-swift-version", "5", "-I", str(work), "-L", str(work), "-lIDeviceSwift",
        "-Xlinker", "-rpath", "-Xlinker", str(work),
        str(ROOT / "Feather/Backend/Observable/InstallerStatusViewModel.swift"),
        str(ROOT / "Tools/Fixtures/InstallStatusTests.swift"),
        "-o", str(status_executable),
    ], check=True)
    subprocess.run([str(status_executable)], check=True)
