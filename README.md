# macOS Local SSL & `.test` Domain Doctor

A lightweight, read-only diagnostic script for macOS developers troubleshooting `.test` domains, Dnsmasq/resolver routing, port `80`/`443` conflicts, and Keychain Root CA trust in Safari & Google Chrome.

## Usage

Inspect and run locally:

```bash
curl -fsSLO https://stratosapp.dev/tools/macos-local-ssl-doctor.sh
bash macos-local-ssl-doctor.sh my-app.test
```

Or run directly against a clone of this repo:

```bash
bash macos-local-ssl-doctor.sh my-app.test
```

## What It Checks

1. **`/etc/resolver/<tld>`**: Verifies that macOS routes `.test` DNS queries to your local DNS server (`127.0.0.1`) and prints the exact command to create it if missing.
2. **Local DNS resolution (`dscacheutil`)**: Confirms your `.test` hostname resolves to `127.0.0.1` instead of timing out.
3. **Ports `80` & `443` listeners (`lsof`)**: Shows processes listening on HTTP/HTTPS ports.
4. **macOS Keychain Root CA (`security find-certificate`)**: Checks whether a local development Root CA (`Stratos`, `Valet`, `Herd`, or `mkcert`) is installed in your Keychain.

> **Need automated zero-warning HTTPS on macOS?**  
> [Stratos](https://stratosapp.dev/download/) provisions a 4096-bit Local Root CA, wildcard `.test` SAN certificates, Dnsmasq, Nginx 1.27, and multi-PHP (8.1–8.5) natively in Swift—free forever for core local hosting.
