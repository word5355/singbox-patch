#!/usr/bin/env python3
"""Insert the INTERACT_ACROSS_USERS permission into a decoded AndroidManifest.xml.

Used on the output of `apktool d`, before `apktool b`. Fails loudly if the
anchor line is missing, so a silent no-op patch never ships (see
https://github.com/SagerNet/sing-box/issues/4246).
"""
import sys

PERMISSION_NAME = "android.permission.INTERACT_ACROSS_USERS"
PERMISSION_LINE = f'    <uses-permission android:name="{PERMISSION_NAME}"/>\n'
ANCHOR = '<uses-permission android:name="android.permission.INTERNET"/>'
# Exact-match marker: a plain substring check on PERMISSION_NAME also matches
# android.permission.INTERACT_ACROSS_USERS_FULL (used elsewhere in the
# manifest, e.g. the Shizuku provider's android:permission attribute), which
# made the script wrongly believe the permission was already present and
# skip patching. Requiring the closing quote rules that out.
ALREADY_PRESENT_MARKER = f'"{PERMISSION_NAME}"'


def patch(path: str) -> None:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    if any(ALREADY_PRESENT_MARKER in line for line in lines):
        print(f"{path}: permission already present, skipping")
        return

    for i, line in enumerate(lines):
        if ANCHOR in line:
            lines.insert(i, PERMISSION_LINE)
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(lines)
            print(f"{path}: inserted {PERMISSION_NAME} before line {i + 1}")
            return

    print(f"ERROR: anchor line not found in {path} -- refusing to build an unpatched APK", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: patch_manifest.py <path-to-AndroidManifest.xml>", file=sys.stderr)
        sys.exit(2)
    patch(sys.argv[1])
