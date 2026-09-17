#!/usr/bin/env bash
# Generates a fresh self-signing keystore for the patched sing-box-for-android
# APKs and prints the 4 values this repo's workflow needs as GitHub Actions
# secrets. Nothing is written to a file (unless you pass --keep-keystore),
# so there's nothing left over to remember to delete.
#
# Run this on YOUR OWN machine (not in a shared/remote session), so the key
# material never passes through anything else. Requires only `keytool`
# (comes with any JDK).
#
# Usage:
#   ./scripts/generate_signing_key.sh
#   ./scripts/generate_signing_key.sh --keep-keystore ~/backup/sfa-release.keystore
#
# Paste the printed values into:
#   GitHub repo > Settings > Secrets and variables > Actions > New repository secret
#
# --keep-keystore PATH also saves a copy of the keystore file at PATH.
# Do this at least once somewhere safe (password manager, encrypted backup):
# GitHub secrets are write-only, so if you lose every copy of the keystore
# you cannot recover it, and future builds will be re-signed with a new key
# (meaning users have to uninstall the old APK before installing the new one).

set -euo pipefail

KEEP_KEYSTORE=""
ALIAS_NAME="sfa-patch"

while [ $# -gt 0 ]; do
  case "$1" in
    --keep-keystore)
      KEEP_KEYSTORE="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,21p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -n "$KEEP_KEYSTORE" ] && [ -c "$KEEP_KEYSTORE" ]; then
  echo "--keep-keystore must be a regular file path, not a device like $KEEP_KEYSTORE." >&2
  echo "The keystore is binary; writing it to a terminal/stdout corrupts your screen." >&2
  echo "The base64 text this script prints under APK_KEYSTORE_BASE64 is the safe way" >&2
  echo "to get the keystore through stdout -- omit --keep-keystore if that's all you need." >&2
  exit 1
fi

command -v keytool >/dev/null 2>&1 || { echo "keytool not found. Install a JDK (e.g. Temurin 17) first." >&2; exit 1; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

KEYSTORE_PATH="$WORKDIR/release.keystore"
KEYSTORE_PASS=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)

echo "Generating RSA 4096 keystore..." >&2
keytool -genkeypair \
  -keystore "$KEYSTORE_PATH" \
  -alias "$ALIAS_NAME" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
  -dname "CN=singbox-patch (unofficial personal build), OU=personal, O=personal, L=NA, ST=NA, C=JP" \
  >/dev/null
# PKCS12 (keytool's default keystore format) requires the store password and
# key password to be identical; the -keypass above is accepted but ignored.

if [ -n "$KEEP_KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEEP_KEYSTORE")"
  cp "$KEYSTORE_PATH" "$KEEP_KEYSTORE"
  echo "Keystore backup saved to $KEEP_KEYSTORE -- move it somewhere durable (password manager, encrypted backup)." >&2
else
  echo "No --keep-keystore given: the keystore file will be discarded after this script exits." >&2
  echo "GitHub secrets are write-only -- without a backup, this key is unrecoverable if you" >&2
  echo "ever need it outside this workflow (e.g. re-signing manually)." >&2
fi

cat >&2 <<'EOF'

Add these 4 as repo secrets:
  GitHub repo > Settings > Secrets and variables > Actions > New repository secret

Your terminal scrollback will hold these values after this runs -- clear it
(or close the terminal) once they're pasted in.

EOF

echo "=== APK_KEYSTORE_BASE64 ==="
base64 -w0 "$KEYSTORE_PATH"
echo ""
echo "=== APK_KEYSTORE_PASS ==="
echo "$KEYSTORE_PASS"
echo "=== APK_KEY_ALIAS ==="
echo "$ALIAS_NAME"
echo "=== APK_KEY_PASS ==="
echo "$KEYSTORE_PASS"

if [ -f "github_secrets_setup.txt" ]; then
  echo "" >&2
  echo "NOTE: a github_secrets_setup.txt from an earlier setup exists here." >&2
  echo "Once you've pasted the values above into GitHub, delete that file:" >&2
  echo "  rm github_secrets_setup.txt" >&2
fi
