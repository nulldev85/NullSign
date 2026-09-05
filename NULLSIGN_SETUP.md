# NullSign

NullSign is a minimal, OLED-first on-device IPA signer based on Feather. It keeps the three core areas: **Signer**, **Apps**, and **Settings**.

## What is included

- Import unsigned IPA files from Files or a URL.
- Sign and install apps using an imported certificate pair.
- Browse apps from user-added AltStore-compatible repositories.
- Import `.p12` and `.mobileprovision` files, validate their password, select the active certificate, inspect it, rename it, check revocation, and delete it.
- True OLED-black appearance with a monochrome interface.

## Build the bootstrap IPA with GitHub Actions

Open **Actions → Build NullSign IPA → Run workflow**. No signing secrets are required. When it finishes, download the `NullSign-unsigned-IPA` artifact.

The first NullSign IPA must be signed once using an existing signer or signing service before iOS can install it. After NullSign is installed, import your `.p12`, its password, and the matching `.mobileprovision` inside **Settings → Import & Manage Certificates**. Those credentials remain on the device and are then used by NullSign to sign other IPAs.

## License

NullSign is a modified version of Feather and remains licensed under GPL-3.0. Keep the original copyright and license notices when distributing builds or source.
