#!/usr/bin/env python3
"""Compile the real importer with pinned Zip; replace only UI/database boundaries."""

import json
import os
from pathlib import Path
import plistlib
import platform
import shlex
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
resolved = json.loads((ROOT / "Feather.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
pin = next(item for item in resolved["pins"] if item["identity"] == "zip")
swiftc = shlex.split(os.environ.get("SWIFTC", "swiftc"))
cc = shlex.split(os.environ.get("CC", "cc"))
cflags = shlex.split(os.environ.get("ZLIB_CFLAGS", ""))
ldflags = shlex.split(os.environ.get("ZLIB_LDFLAGS", ""))
target = ["-target", f"{platform.machine()}-apple-macosx13.0"] if sys.platform == "darwin" else []


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


with tempfile.TemporaryDirectory(prefix="nullsign-import-tests-") as directory:
    work = Path(directory)
    if os.environ.get("ZIP_SOURCE"):
        checkout = Path(os.environ["ZIP_SOURCE"])
    else:
        checkout = work / "Zip"
        run("git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", pin["location"], checkout)
        run("git", "-C", checkout, "checkout", "--quiet", pin["state"]["revision"])
    revision = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    assert revision == pin["state"]["revision"], "Test the same ZIP revision as the app"
    source = checkout / "Zip"
    includes = source / "minizip/include"
    objects = []
    for name in ("ioapi", "unzip", "zip"):
        output = work / f"{name}.o"
        run(*cc, "-c", "-fPIC", f"-I{includes}", *cflags, source / f"minizip/{name}.c", "-o", output)
        objects.append(output)
    (work / "module.modulemap").write_text(
        f'module Minizip [system] {{ header "{includes / "Minizip.h"}" link "z" export * }}\n')
    swift_sources = []
    for original in sorted(source.glob("*.swift")):
        copied = work / original.name
        text = original.read_text()
        if sys.platform == "linux" and original.name == "Zip.swift":
            # New Linux libc imports mark fwrite's pointer nonoptional. The
            # pinned source already guards it in `while filePointer != nil`.
            text = text.replace("fwrite(buffer, Int(readBytes), 1, filePointer)",
                                "fwrite(buffer, Int(readBytes), 1, filePointer!)")
        copied.write_text(text)
        swift_sources.append(copied)
    suffix = "dylib" if sys.platform == "darwin" else "so"
    swift_cflags = [part for flag in cflags for part in ("-Xcc", flag)]
    run(*swiftc, "-swift-version", "5", *target, "-emit-module", "-emit-library", "-module-name", "Zip",
        "-I", work, *swift_cflags, *ldflags, *swift_sources, *objects,
        "-emit-module-path", work / "Zip.swiftmodule", "-o", work / f"libZip.{suffix}")
    helpers = []
    for relative in ("NimbleKit/Sources/NimbleExtensions/FileManager/FileManager+shortcuts.swift",
                     "NimbleKit/Sources/NimbleExtensions/Bundle/Bundle+keys.swift"):
        original = ROOT / relative
        if sys.platform == "linux":
            # Linux Foundation has no Objective-C submodules; the helpers are unchanged.
            copied = work / original.name
            copied.write_text(original.read_text().replace("import Foundation.NSFileManager", "import Foundation")
                              .replace("import Foundation.NSBundle", "import Foundation"))
            helpers.append(copied)
        else:
            helpers.append(original)
    run(*swiftc, "-swift-version", "5", *target, "-I", work, "-L", work, "-lZip", *ldflags,
        "-Xlinker", "-rpath", "-Xlinker", work,
        *helpers,
        ROOT / "Feather/Utilities/Handlers/AppFileHandler.swift",
        ROOT / "Tools/Fixtures/AppImportTests.swift", "-o", work / "test-import")
    (work / "Unsigned").mkdir()
    for index in range(36):
        folder = work / "Inputs" / str(index)
        folder.mkdir(parents=True)
        archive = folder / ("App.tipa" if index % 2 else "App.ipa")
        if index == 33:
            archive.write_bytes(b"corrupt archive")
            continue
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as ipa:
            if index == 34:
                ipa.writestr("Payload/readme.txt", "No app bundle")
                continue
            identifier = f"com.nullsign.fixture.{index}" if index != 35 else "com.nullsign.fixture.reject"
            info = plistlib.dumps({
                "CFBundleIdentifier": identifier, "CFBundleName": f"Fixture {index}",
                "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
                "CFBundleExecutable": "Fixture",
            })
            ipa.writestr("Payload/Fixture.app/Info.plist", info)
            if sys.platform == "linux":
                # Linux Bundle treats a Resources directory as the metadata root.
                ipa.writestr("Payload/Fixture.app/Resources/Info.plist", info)
            ipa.writestr("Payload/Fixture.app/Fixture", b"fixture executable")
            for resource in range(1500 if index == 32 else 10):
                ipa.writestr(f"Payload/Fixture.app/Resources/{resource}.txt", str(resource) * 30)
    run(work / "test-import", work)
