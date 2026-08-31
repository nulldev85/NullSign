# NullSign

NullSign is a minimal, OLED-first on-device IPA signer based on Feather. It keeps the three core areas: **Signer**, **Apps**, and **Settings**.

## What is included

- Import unsigned IPA files from Files or a URL.
- Sign and install apps using an imported certificate pair.
- Browse apps from user-added AltStore-compatible repositories.
- Import `.p12` and `.mobileprovision` files, validate their password, select the active certificate, inspect it, rename it, check revocation, and delete it.
- OLED-black appearance with an electric-cyan accent.

## Build a signed IPA with GitHub Actions

Create a private GitHub repository and add these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 contents of the Apple Distribution `.p12` file |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 contents of the Ad Hoc `.mobileprovision` |
| `KEYCHAIN_PASSWORD` | A new random password used only by the temporary CI keychain |
| `DEVELOPMENT_TEAM` | The 10-character Apple Developer Team ID |
| `BUNDLE_IDENTIFIER` | Bundle ID in the profile, for example `com.elmat.NullSign` |

The Ad Hoc provisioning profile must contain the iPhone's UDID and match `BUNDLE_IDENTIFIER`.

Open **Actions → Build signed NullSign IPA → Run workflow**. When it finishes, download the `NullSign-IPA` artifact. GitHub deletes the temporary keychain and decoded signing files with the runner.

## License

NullSign is a modified version of Feather and remains licensed under GPL-3.0. Keep the original copyright and license notices when distributing builds or source.
