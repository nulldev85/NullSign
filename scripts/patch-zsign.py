#!/usr/bin/env python3
"""Keep the provisioning profile Zsign embeds.

The pinned Zsign writes embedded.mobileprovision when NullSign asks for it,
then deletes it again while it seals the bundle's resources, because both
steps read the same flag. Signed apps then carry no profile, and a device
without that profile installed (a new Apple TV in particular) refuses them
with "A valid provisioning profile for this executable was not found".

This removes the deletion, so the flag only decides whether the profile is
written. Run before building; it's safe to run more than once.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "Zsign" / "src" / "bundle.cpp"

DELETION = """		if (m_bRemoveProvision && strKey == "embedded.mobileprovision") {
			string strProvFile = strFolder + "/embedded.mobileprovision";
			remove(strProvFile.c_str());
			ZLog::Print(">>> Removed embedded.mobileprovision\\n");
			continue;
		}
"""
MARKER = "// NullSign: the profile written for this bundle stays in it."

source = BUNDLE.read_text()
if MARKER in source:
    print("Zsign already keeps the embedded profile.")
    sys.exit(0)
if source.count(DELETION) != 1:
    sys.exit(f"{BUNDLE}: the embedded profile deletion moved; update scripts/patch-zsign.py.")

BUNDLE.write_text(source.replace(DELETION, "\t\t" + MARKER + "\n"))
print("Zsign now keeps the embedded profile.")
