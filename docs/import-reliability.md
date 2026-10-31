# Certificate and batch IPA import reliability

Reported October 31, 2026; changes based on main `f2632d2` (1.4.3, build 32).

## Certificate imports

The previous alert combined every PKCS#12 password-check failure into the same
message. It did not compare the signing identity with the selected profile.
The check verified only the MAC, so a usable passwordless PKCS#12 file without
a MAC was rejected. The regression suite reproduces this rejection with the
old implementation and opens the same generated identity with the replacement.

The importer now explicitly initializes OpenSSL's default and optional legacy
providers once, decrypts the identity using the same parser as the signer,
requires a private key, and checks the profile's DeveloperCertificates against
the signing certificate/key. Passwords are preserved exactly. Errors distinguish
unreadable files, malformed certificates, password/decryption failures, missing
private keys, invalid profiles, and mismatched pairs.

Provisioning profiles are decoded from their CMS payload rather than scanning
for an XML header and passing the binary trailer to the plist decoder. XML and
binary payloads work; DER-Encoded-Profile is optional for older profiles. All
entry points use the same background validation path. File access scopes cover
validation and copying, saves finish before success is reported, and failed
imports remove partial files.

The tester's actual certificate/password were not supplied. The screenshot
alone cannot identify which error applies to that particular identity.

## Multiple IPA imports

Each import previously called Zip.addCustomFileExtension from a detached task.
Zip 2.1.2 mutates a shared, unsynchronized Set there while other imports read it.
This is a concrete data race and a potential cause of batch-import crashes;
the reported device crash has not been confirmed with a crash log.

Every import now copies its IPA/TIPA into its existing unique work directory as
Archive.zip, eliminating custom-extension writes. Decompression runs on one
utility queue, with at most 101 progress notifications per archive. File access
scopes are balanced around copying. Remote downloads also have individual staging
directories so identical suggested filenames cannot overwrite another import.

Library inserts are awaited. A failed database save propagates an error; corrupt
archives, archives without an app, and failed saves remove partial library files.
Other files in the batch continue importing.

## Verification

Passed locally on the Linux host:

- 15 generated-certificate tests, including modern/legacy encryption, empty and
  Unicode passwords, omitted MAC, wrong passwords, malformed files, exact profile
  matching, binary/XML CMS payloads, repeated imports, and actual signer loading.
- Four actual Swift certificate-model cases covering XML/binary profiles with
  and without DER-Encoded-Profile.
- The actual AppFileHandler with the pinned Zip 2.1.2 implementation: 33 concurrent
  valid IPA/TIPA imports sharing filenames, three deliberate failures (corruption,
  missing app, rejected save), unique saved identities, bounded progress, and
  cleanup. UI/background-task/database services are controlled test boundaries.
  Linux-only fixture adaptations cover Foundation imports, bundle layout, security
  scopes, and the pinned ZIP source's libc pointer annotation. macOS tests use the
  unmodified pinned ZIP source and platform APIs.
- Seven existing native signing/resource regressions.
- Clean dependency patch application, repeated preparation, and refusal to
  overwrite unreviewed local edits.
- Changed Swift files parse for an iOS target; typography and whitespace checks.

The build workflow runs the new regressions. The dependency fix is stored as a
reviewed, hash-checked patch through Tools/prepare-zsign.py; the submodule pin and
existing unreadable-resource patch are preserved.

An Apple SDK build and physical-device tester confirmation remain pending. No
new IPA or release has been published by this change.
