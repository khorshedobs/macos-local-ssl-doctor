#!/usr/bin/env bash
set -uo pipefail

# macos-local-ssl-doctor.sh
# Read-only diagnostic helper for .test DNS resolution, ports 80/443, and local Root CA trust on macOS.
# Part of Stratos open-source sidecar tools (https://stratosapp.dev)

DOMAIN="${1:-app.test}"
TLD="${DOMAIN##*.}"
if [ -z "$TLD" ] || [ "$TLD" = "$DOMAIN" ]; then
  TLD="test"
fi

RESOLVER_FILE="/etc/resolver/${TLD}"
ISSUES=0

echo "================================================================"
echo " macOS Local SSL & .test Domain Doctor"
echo " Target domain: ${DOMAIN} (TLD: .${TLD})"
echo "================================================================"
echo ""

# 1. Resolver check (/etc/resolver/<tld>)
echo "[1/4] Checking macOS resolver file (${RESOLVER_FILE})..."
if [ -f "$RESOLVER_FILE" ]; then
  echo "  OK: Found ${RESOLVER_FILE}"
  sed 's/^/      /' "$RESOLVER_FILE"
else
  echo "  FAIL: Missing ${RESOLVER_FILE} — macOS will not route *.${TLD} to a local DNS server."
  echo "  Fix:  sudo mkdir -p /etc/resolver && printf \"nameserver 127.0.0.1\\nport 53535\\n\" | sudo tee ${RESOLVER_FILE}"
  ISSUES=$((ISSUES + 1))
fi
echo ""

# 2. Local DNS resolution check (dscacheutil)
echo "[2/4] Checking local DNS resolution for ${DOMAIN}..."
DNS_OUT="$(/usr/bin/dscacheutil -q host -a name "$DOMAIN" 2>/dev/null || true)"
if echo "$DNS_OUT" | grep -qE "ip_address:\s*(127\.0\.0\.1|::1)"; then
  echo "  OK: ${DOMAIN} resolves locally:"
  echo "$DNS_OUT" | grep -E "name:|ip_address:" | sed 's/^/      /'
else
  echo "  WARN: ${DOMAIN} did not resolve to 127.0.0.1 via dscacheutil."
  if [ -n "$DNS_OUT" ]; then
    echo "$DNS_OUT" | sed 's/^/      /'
  fi
  echo "  Fix:  Ensure dnsmasq/local DNS is running, then run:"
  echo "        sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
  ISSUES=$((ISSUES + 1))
fi
echo ""

# 3. Port 80 / 443 listener check
echo "[3/4] Checking listeners on ports 80 and 443..."
LSOF_BIN="/usr/sbin/lsof"
if [ ! -x "$LSOF_BIN" ]; then
  LSOF_BIN="$(command -v lsof || true)"
fi

if [ -n "$LSOF_BIN" ]; then
  PORT80="$("$LSOF_BIN" -nP -iTCP:80 -sTCP:LISTEN 2>/dev/null || true)"
  PORT443="$("$LSOF_BIN" -nP -iTCP:443 -sTCP:LISTEN 2>/dev/null || true)"

  if [ -n "$PORT80" ]; then
    echo "  Port 80 listener(s):"
    echo "$PORT80" | head -n 5 | sed 's/^/      /'
  else
    echo "  INFO: No user-visible listener on port 80 (root-owned daemons may require: sudo lsof -nP -iTCP:80 -sTCP:LISTEN)."
  fi

  if [ -n "$PORT443" ]; then
    echo "  Port 443 listener(s):"
    echo "$PORT443" | head -n 5 | sed 's/^/      /'
  else
    echo "  INFO: No user-visible listener on port 443 (root-owned daemons may require: sudo lsof -nP -iTCP:443 -sTCP:LISTEN)."
  fi

  if [ -z "$PORT80" ] && [ -z "$PORT443" ]; then
    echo "  WARN: Neither port 80 nor 443 showed a user-visible listener."
  fi
else
  echo "  WARN: lsof not found; skipping port check."
fi
echo ""

# 4. macOS Keychain Root CA check
echo "[4/4] Checking macOS Keychain for local development Root CA certificates..."
FOUND_CAS=0
for CA_NAME in "Stratos" "Valet" "Herd" "mkcert"; do
  CERT_MATCH="$(/usr/bin/security find-certificate -a -c "$CA_NAME" 2>/dev/null | grep -E "labl|alis" | head -n 2 || true)"
  if [ -n "$CERT_MATCH" ]; then
    echo "  OK: Found ${CA_NAME} certificate in Keychain:"
    echo "$CERT_MATCH" | sed 's/^/      /'
    FOUND_CAS=$((FOUND_CAS + 1))
  fi
done

if [ "$FOUND_CAS" -eq 0 ]; then
  echo "  FAIL: No Stratos, Valet, Herd, or mkcert Root CA found in user/system Keychain."
  echo "  Fix:  Open Keychain Access and trust your local Root CA, or install Stratos to provision a 4096-bit Root CA automatically."
  ISSUES=$((ISSUES + 1))
fi
echo ""

echo "================================================================"
if [ "$ISSUES" -eq 0 ]; then
  echo " Summary: Core local DNS and Root CA checks passed."
else
  echo " Summary: Detected ${ISSUES} configuration issue(s) above."
fi
echo "💡 Tired of manual Keychain & Dnsmasq fixes? Stratos handles zero-warning Root CA SSL & PHP 8.1–8.5 natively for free -> https://stratosapp.dev/download/"
echo "================================================================"
