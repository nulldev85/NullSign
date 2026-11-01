#!/usr/bin/env python3
"""Generate disposable identities and exercise the real importer/signing engine."""

import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CertificateImport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="nullsign-certificate-tests-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        cls.binary = cls.root / "test-certificate-import"
        spec = importlib.util.spec_from_file_location("resource_tests", ROOT / "Tools/test-zsign-resources.py")
        resources = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(resources)
        source = ROOT / "Zsign/src"
        names = ["archo.cpp", "bundle.cpp", "macho.cpp", "openssl.cpp", "signing.cpp",
                 "common/base64.cpp", "common/fs.cpp", "common/json.cpp", "common/log.cpp",
                 "common/sha.cpp", "common/timer.cpp", "common/util.cpp"]
        subprocess.run([
            os.environ.get("CXX", "c++"), "-std=c++17", "-O1", "-Wno-deprecated-declarations", "-Wno-format",
            f"-I{source}", f"-I{source / 'common'}", str(ROOT / "Tools/test-certificate-import.cpp"),
            *(str(source / name) for name in names), *resources.openssl_flags(), "-o", str(cls.binary),
        ], check=True)
        for identity in ("one", "two"):
            cls.openssl("req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", f"/CN=NullSign Test {identity}", "-keyout", f"{identity}.key", "-out", f"{identity}.pem")
            cls.openssl("x509", "-in", f"{identity}.pem", "-outform", "DER", "-out", f"{identity}.der")
        cls.export("modern", "fixture-password")
        cls.export("legacy", "fixture-password", "-legacy")
        cls.export("empty", "")
        cls.export("empty-nomac", "", "-nomac")
        cls.export("unicode", "p\u00e4ss\U0001f512 with spaces")
        cls.openssl("pkcs12", "-export", "-nokeys", "-in", "one.pem", "-out", "certificate-only.p12",
                    "-passout", "pass:fixture-password")
        # Same key, different certificate: the exact identity must be in the profile.
        cls.openssl("req", "-new", "-x509", "-key", "one.key", "-days", "1", "-set_serial", "999",
                    "-subj", "/CN=Renewed NullSign Test", "-out", "renewed.pem")
        cls.openssl("x509", "-in", "renewed.pem", "-outform", "DER", "-out", "renewed.der")
        cls.profile("matching", ["one"])
        cls.profile("mismatched", ["two"])
        cls.profile("multiple", ["two", "one"])
        cls.profile("renewed", ["renewed"])
        cls.profile("binary", ["one"], fmt=plistlib.FMT_BINARY)
        cls.profile("missing-certificates", [])
        (cls.root / "invalid.p12").write_bytes(b"not a pkcs12 file")
        (cls.root / "invalid.mobileprovision").write_bytes(b"not a profile")

    @classmethod
    def openssl(cls, *args):
        subprocess.run(["openssl", *args], cwd=cls.root, check=True, capture_output=True)

    @classmethod
    def export(cls, name, password, *options):
        cls.openssl("pkcs12", "-export", "-inkey", "one.key", "-in", "one.pem",
                    "-out", f"{name}.p12", "-passout", f"pass:{password}", *options)

    @classmethod
    def profile(cls, name, identities, fmt=plistlib.FMT_XML):
        payload = plistlib.dumps({
            "TeamIdentifier": ["NULLSIGN01"], "Entitlements": {"application-identifier": "NULLSIGN01.*"},
            "DeveloperCertificates": [(cls.root / f"{identity}.der").read_bytes() for identity in identities],
        }, fmt=fmt)
        (cls.root / f"{name}.plist").write_bytes(payload)
        cls.openssl("cms", "-sign", "-binary", "-nodetach", "-signer", "two.pem", "-inkey", "two.key",
                    "-in", f"{name}.plist", "-outform", "DER", "-out", f"{name}.mobileprovision")

    def run_native(self, p12="modern", password="fixture-password", profile="matching", mode="check"):
        return subprocess.run([str(self.binary), mode, str(self.root / f"{p12}.p12"), password,
                               str(self.root / f"{profile}.mobileprovision")], capture_output=True)

    def assert_status(self, expected, **kwargs):
        result = self.run_native(**kwargs)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout.decode().strip(), expected)

    def test_modern_identity_in_fresh_process(self):
        self.assert_status("valid")

    def test_legacy_identity_in_fresh_process(self):
        self.assert_status("valid", p12="legacy")

    def test_passwordless_identity(self):
        self.assert_status("valid", p12="empty", password="")

    def test_passwordless_identity_without_mac(self):
        self.assert_status("valid", p12="empty-nomac", password="")

    def test_wrong_and_missing_passwords(self):
        for password in ("", "wrong", " fixture-password", "fixture-password "):
            with self.subTest(password=password):
                self.assert_status("incorrectPassword", password=password)

    def test_empty_password_identity_does_not_ignore_supplied_password(self):
        self.assert_status("incorrectPassword", p12="empty", password="wrong")

    def test_unicode_password_is_preserved(self):
        self.assert_status("valid", p12="unicode", password="p\u00e4ss\U0001f512 with spaces")

    def test_missing_and_corrupt_certificate(self):
        self.assert_status("unreadableCertificate", p12="missing")
        self.assert_status("invalidCertificate", p12="invalid")

    def test_private_key_required(self):
        self.assert_status("missingPrivateKey", p12="certificate-only")

    def test_missing_and_invalid_profile(self):
        self.assert_status("unreadableProfile", profile="missing")
        self.assert_status("invalidProfile", profile="invalid")
        self.assert_status("invalidProfile", profile="missing-certificates")

    def test_profile_must_include_exact_certificate(self):
        self.assert_status("profileMismatch", profile="mismatched")
        self.assert_status("profileMismatch", profile="renewed")
        self.assert_status("valid", profile="multiple")

    def test_xml_and_binary_profile_content_excludes_cms_trailer(self):
        for profile in ("matching", "binary"):
            with self.subTest(profile=profile):
                result = self.run_native(profile=profile, mode="content")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, (self.root / f"{profile}.plist").read_bytes())
                self.assert_status("valid", profile=profile)

    def test_repeated_imports(self):
        self.assert_status("valid", mode="repeat")

    def test_imported_identities_open_in_actual_signer(self):
        for p12, password in (("modern", "fixture-password"), ("legacy", "fixture-password"),
                              ("empty", ""), ("empty-nomac", ""), ("unicode", "p\u00e4ss\U0001f512 with spaces")):
            with self.subTest(p12=p12):
                result = self.run_native(p12=p12, password=password, mode="signing-init")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_original_check_rejects_valid_passwordless_identity_without_mac(self):
        self.assert_status("rejected", p12="empty-nomac", password="", mode="old-check")
        self.assert_status("valid", p12="empty-nomac", password="")


if __name__ == "__main__":
    unittest.main(verbosity=2)
