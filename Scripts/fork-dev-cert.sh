#!/bin/bash
# Fork: create the self-signed "OmniWM Dev" code-signing identity that
# package-app.sh uses for Dev builds, so macOS keeps OmniWM Dev's permissions
# across rebuilds. Same result as the Keychain Access steps in CONTRIBUTING.md,
# plus the key partition list that stops codesign prompting on every build.
#
# Run it in your own terminal: it asks for your password twice (trust settings,
# then the login keychain). An agent's shell can't show those prompts.

set -euo pipefail

name="${OMNIWM_SIGNING_IDENTITY:-OmniWM Dev}"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -qF "\"$name\""; then
  echo "A valid \"$name\" code-signing identity already exists:"
  security find-identity -v -p codesigning | grep -F "\"$name\""
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

cat > cert.cnf <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# macOS's own LibreSSL on purpose: a PKCS#12 from Homebrew's OpenSSL 3 often
# fails to import into the keychain.
echo "Creating certificate..."
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config cert.cnf -keyout key.pem -out cert.pem 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey key.pem -in cert.pem \
  -name "$name" -passout pass:omniwm -out cert.p12

echo "Importing into the login keychain..."
security import cert.p12 -k "$keychain" -P omniwm -T /usr/bin/codesign

echo "Trusting it for code signing (macOS asks for your password)..."
security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" cert.pem

echo "Letting codesign use the key without prompting (enter your login keychain password)..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -l "$name" "$keychain" >/dev/null

echo
if security find-identity -v -p codesigning | grep -F "\"$name\""; then
  echo "Done."
else
  echo "The certificate was imported but isn't trusted for code signing," >&2
  echo "so Dev builds will fall back to ad-hoc signing." >&2
  exit 1
fi
