#!/usr/bin/env python3
"""Exercise the production Debian reader, including bytes from the built IPA."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def packaged_ellekit(ipa: Path, source: Path) -> bytes:
    with zipfile.ZipFile(ipa) as archive:
        names = [name for name in archive.namelist()
                 if name.startswith("Payload/") and name.count("/") == 2
                 and name.endswith(".app/ellekit.deb")]
        if len(names) != 1:
            raise ValueError("The IPA must contain exactly one bundled ellekit.deb")
        content = archive.read(names[0])
    if content != source.read_bytes():
        raise ValueError("Packaged ellekit.deb differs from source; copied Debian archives must not be stripped")
    print("PASS packaged ElleKit is byte-identical to source: SHA256 "
          + hashlib.sha256(content).hexdigest(), flush=True)
    return content


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    source = ROOT / "Feather/Resources/ellekit.deb"
    with tempfile.TemporaryDirectory(prefix="nullsign-ar-tests-") as directory:
        work = Path(directory)
        inputs = [source]
        if args.ipa:
            packaged = work / "packaged-ellekit.deb"
            packaged.write_bytes(packaged_ellekit(args.ipa, source))
            inputs.append(packaged)
        for optimization in ["-Onone", "-O"]:
            executable = work / ("ar-tests" + optimization)
            subprocess.run([
                "xcrun", "swiftc", "-swift-version", "5", optimization,
                str(ROOT / "Feather/Utilities/ARDecompression/AR.swift"),
                str(ROOT / "Feather/Utilities/ARDecompression/Models/ARFileModel.swift"),
                str(ROOT / "Tools/Fixtures/ARDecompressionTests.swift"),
                "-o", str(executable),
            ], check=True, timeout=60)
            subprocess.run([str(executable), *map(str, inputs)], check=True, timeout=30)
            print("PASS production ar reader " + optimization, flush=True)


if __name__ == "__main__":
    main()
