#!/usr/bin/env python3
"""Native resource-hashing and ad-hoc signing regressions (macOS or Linux)."""

import base64
import hashlib
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import struct
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def openssl_flags():
    prefix = os.environ.get("OPENSSL_PREFIX")
    if prefix:
        return [f"-I{prefix}/include", f"-L{prefix}/lib", "-lcrypto", "-lssl"]
    if shutil.which("pkg-config"):
        result = subprocess.run(
            ["pkg-config", "--cflags", "--libs", "openssl"], capture_output=True, text=True
        )
        if result.returncode == 0:
            return shlex.split(result.stdout)
    prefix = subprocess.check_output(["brew", "--prefix", "openssl@3"], text=True).strip()
    return [f"-I{prefix}/include", f"-L{prefix}/lib", "-lcrypto", "-lssl"]


class SigningResources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="nullsign-zsign-tests-")
        cls.addClassCleanup(cls.build.cleanup)
        cls.binary = Path(cls.build.name) / "test-zsign"
        source = ROOT / "Zsign/src"
        names = [
            "archo.cpp", "bundle.cpp", "macho.cpp", "openssl.cpp", "signing.cpp",
            "common/base64.cpp", "common/fs.cpp", "common/json.cpp", "common/log.cpp",
            "common/sha.cpp", "common/timer.cpp", "common/util.cpp",
        ]
        subprocess.run([
            os.environ.get("CXX", "c++"), "-std=c++17", "-O1", "-Wno-deprecated-declarations",
            "-Wno-format", f"-I{source}", f"-I{source / 'common'}",
            str(ROOT / "Tools/test-zsign-resources.cpp"),
            *(str(source / name) for name in names), *openssl_flags(), "-o", str(cls.binary),
        ], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nullsign-app-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_native(self, command, path):
        return subprocess.run([str(self.binary), command, str(path)], capture_output=True, text=True)

    def make_app(self, path=None):
        app = path or self.root / "Fixture.app"
        app.mkdir(parents=True)
        (app / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "com.nullsign.signing-fixture",
            "CFBundleExecutable": "Fixture", "CFBundleName": "Signing Fixture",
            "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
        }))
        # Minimal arm64 executable with reserved signature space, never executed.
        header = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 2, 3, 160, 0x200085, 0)
        text = struct.pack("<II16sQQQQiiII", 0x19, 72, b"__TEXT", 0x100000000, 8192, 0, 8192, 5, 5, 0, 0)
        link = struct.pack("<II16sQQQQiiII", 0x19, 72, b"__LINKEDIT", 0x100002000, 16384, 8192, 16384, 1, 1, 0, 0)
        signature = struct.pack("<IIII", 0x1D, 16, 8192, 16384)
        binary = (header + text + link + signature).ljust(8192, b"\0")
        binary += struct.pack(">III", 0xFADE0CC0, 16384, 0) + b"\0" * (16384 - 12)
        (app / "Fixture").write_bytes(binary)
        return app

    def test_missing_resource_does_not_hash_as_empty(self):
        result = self.run_native("hash", self.root / "missing")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_broken_link_does_not_hash_as_empty(self):
        resource = self.root / "broken"
        resource.symlink_to("missing-target")
        self.assertEqual(self.run_native("hash", resource).returncode, 1)

    def assert_hashes(self, payload):
        path = self.root / "resource"
        path.write_bytes(payload)
        result = self.run_native("hash", path)
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = [base64.b64encode(h(payload).digest()).decode() for h in (hashlib.sha1, hashlib.sha256)]
        self.assertEqual(result.stdout.splitlines(), expected)

    def test_empty_file_still_hashes_correctly(self):
        self.assert_hashes(b"")

    def test_nonempty_file_still_hashes_correctly(self):
        self.assert_hashes(b"NullSign resource\x00\xff" * 3000)

    def test_real_bundle_signing_preserves_resource_seals(self):
        app = self.make_app()
        resources = {"ordinary.txt": b"original resource", "nested/empty": b"", "nested/Spaced caf\u00e9.txt": b"nested"}
        for name, payload in resources.items():
            path = app / name
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(payload)
        (app / "existing-link").symlink_to("ordinary.txt")
        resources["existing-link"] = resources["ordinary.txt"]
        result = self.run_native("sign", app)
        self.assertEqual(result.returncode, 0, result.stderr)
        seals = plistlib.loads((app / "_CodeSignature/CodeResources").read_bytes())
        for name, payload in resources.items():
            self.assertEqual(seals["files"][name], hashlib.sha1(payload).digest())
            self.assertEqual(seals["files2"][name]["hash"], hashlib.sha1(payload).digest())
            self.assertEqual(seals["files2"][name]["hash2"], hashlib.sha256(payload).digest())
        self.assertEqual(self.run_native("verify", app / "Fixture").returncode, 0)

    def test_unreadable_resource_stops_signing_before_seal_is_written(self):
        app = self.make_app()
        (app / "broken-resource").symlink_to("missing-target")
        result = self.run_native("sign", app)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse((app / "_CodeSignature/CodeResources").exists())

    def test_nested_resource_failure_stops_parent_signing(self):
        app = self.make_app()
        plugin = self.make_app(app / "PlugIns/Child.appex")
        (plugin / "broken-resource").symlink_to("missing-target")
        self.assertEqual(self.run_native("sign", app).returncode, 1)
        self.assertFalse((app / "_CodeSignature/CodeResources").exists())
        self.assertFalse((plugin / "_CodeSignature/CodeResources").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
