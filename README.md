# singbox-patch

sing-box-for-android on Android 17+ blocks cross-profile loopback traffic by
default (e.g. sharing a proxy on `127.0.0.1` with a work profile or Private
Space), and upstream hasn't picked up the one-line manifest fix for it:
[SagerNet/sing-box#4246](https://github.com/SagerNet/sing-box/issues/4246).

This repo is a small, unofficial, GitHub-Actions-only pipeline that:

- Watches upstream (`SagerNet/sing-box`) releases for new APK assets.
- Adds `android.permission.INTERACT_ACROSS_USERS` to the official
  sing-box-for-android release APK by decoding it with `apktool`, patching
  the manifest, and rebuilding it — the app itself stays byte-identical to
  the official release aside from that one manifest line.
- Re-signs it with a key you generate yourself and publishes it as a release
  on this repo, which [Obtainium](https://github.com/ImranR98/Obtainium) can
  track for auto-installs (`io.nekohasekai.sfa`, same applicationId as the
  official app). The release notes carry over upstream's own release notes,
  after a notice that this is a patched, unofficial build.
- Builds one ABI, `arm64-v8a` by default — change the `DEFAULT_ABI` value
  near the top of the workflow file to build a different one (`armeabi-v7a`,
  `x86_64`, etc.) on the schedule trigger, or pass an `abi` input when
  running the workflow manually for a one-off.

**Not affiliated with SagerNet.** Use at your own risk — it installs an app
signed with a key that isn't SagerNet's; see [Known
caveats](#known-caveats) below.

## Setup

### Prerequisites

- A JDK (e.g. Temurin 17), for `keytool` — used only to generate the signing
  key in step 2 below, on your own machine.
- `git` and a GitHub account (the rest of the build runs entirely in GitHub
  Actions; nothing else needs installing locally).
- [Obtainium](https://github.com/ImranR98/Obtainium) on the Android device,
  if you want auto-installs.

### Steps

1. Fork or clone this repo, and push it to your own GitHub (public repo
   recommended: unlimited Actions minutes).
2. Generate a signing key on your own machine:

   ```
   ./scripts/generate_signing_key.sh --keep-keystore ~/secure/sfa-release.keystore
   ```

   This generates a new key with `keytool` alone and prints the 4 values
   `APK_KEYSTORE_BASE64` / `APK_KEYSTORE_PASS` / `APK_KEY_ALIAS` /
   `APK_KEY_PASS` to stdout (nothing is written to a file). Paste each one
   into GitHub repo > Settings > Secrets and variables > Actions > New
   repository secret. Clear or close your terminal scrollback afterward.
   `--keep-keystore` additionally saves a backup copy of the keystore file
   at the given path (GitHub secrets are write-only and can't be read back,
   so losing every copy means you can never re-sign again — keep this
   backup somewhere durable).
3. From the Actions tab, manually run `Build patched sing-box-for-android
   APKs` (`workflow_dispatch`) once to confirm it works. The cron trigger is
   already enabled, so after that it checks every 6 hours automatically.
4. In Obtainium, "Add App" -> GitHub URL -> point it at this repo.

## Known caveats

- **The signature differs from the official app, so if the official app is
  already installed you must uninstall it first** (the `applicationId`
  stays `io.nekohasekai.sfa`, so future updates from this repo will install
  over each other fine).
- By default the workflow also tracks prereleases (alpha/beta/rc), not just
  stable. Set `DEFAULT_INCLUDE_PRERELEASES` to `"false"` near the top of the
  workflow to track stable only on the schedule trigger, or pass
  `include_prereleases: false` on a manual run.
- `publish_android` is a manual `workflow_dispatch` job upstream, so there
  can be a lag between a tag being created and its APK assets being
  attached. This workflow keys off "do SFA-*.apk assets exist" rather than
  tag freshness, so a release without assets yet is simply skipped until
  the next poll.

See [NOTES.md](NOTES.md) for what was verified on-device about how
cross-profile loopback actually behaves, and other implementation notes.

## License

This repo's own code (the workflow, `scripts/patch_manifest.py`,
`scripts/generate_signing_key.sh`) is licensed under the GNU General Public
License v3.0 or later (`GPL-3.0-or-later`) — see [LICENSE](LICENSE).

The APKs this repo publishes are modified versions of
[sing-box-for-android](https://github.com/SagerNet/sing-box-for-android)
(Copyright (C) nekohasekai), licensed `GPL-3.0-or-later`, with an added
restriction that no derivative work may use its name or imply association
with it without prior consent — hence "unofficial" and "not affiliated with
SagerNet" throughout this README and every release. The only change from
upstream's own released binary is the one manifest line added by
`scripts/patch_manifest.py` (linked from every release); upstream's own
source is at the link above.
