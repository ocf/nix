#!/usr/bin/env python3
"""Push Nix store paths to the OCF binary cache via SPNEGO + OIDC."""

import base64
import hashlib
import os
import secrets
import subprocess
import sys
import tempfile
import urllib.parse

import requests
from requests_kerberos import OPTIONAL, HTTPKerberosAuth

REALM = "https://idm.ocf.berkeley.edu/realms/ocf/protocol/openid-connect"
CLIENT_ID = "niks3"
REDIRECT_URI = "http://127.0.0.1/cb"
SERVER_URL = "https://cache.ocf.berkeley.edu"


def pkce_pair():
    """Generate a PKCE code verifier and its S256 challenge."""
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).rstrip(b"=").decode()
    return verifier, challenge


def get_token():
    """Authenticate to Keycloak via SPNEGO and return an OIDC access token."""
    verifier, challenge = pkce_pair()
    state = secrets.token_urlsafe(16)

    # SPNEGO auth request — Keycloak sees the Kerberos ticket and redirects
    # with an authorization code. We intercept the redirect instead of following it.
    resp = requests.get(
        f"{REALM}/auth?" + urllib.parse.urlencode({
            "client_id": CLIENT_ID,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": "openid groups",
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }),
        auth=HTTPKerberosAuth(mutual_authentication=OPTIONAL),
        allow_redirects=False,
        timeout=15,
    )
    if resp.status_code == 401:
        sys.exit("No valid Kerberos ticket. Run: kinit")
    if resp.status_code not in (302, 303):
        sys.exit(f"Unexpected response from Keycloak: {resp.status_code}")

    # Extract the authorization code from the redirect Location header.
    qs = urllib.parse.parse_qs(urllib.parse.urlparse(resp.headers["Location"]).query)
    if "error" in qs:
        sys.exit(f"OAuth error: {qs['error'][0]}")
    assert qs.get("state", [None])[0] == state, "OAuth state mismatch"

    # Exchange the code for an access token.
    resp = requests.post(f"{REALM}/token", timeout=15, data={
        "grant_type": "authorization_code",
        "client_id": CLIENT_ID,
        "code": qs["code"][0],
        "redirect_uri": REDIRECT_URI,
        "code_verifier": verifier,
    })
    resp.raise_for_status()
    return resp.json()["access_token"]


def main():
    if len(sys.argv) < 2:
        sys.exit(f"Usage: {sys.argv[0]} <store-path>...")

    token = get_token()

    # niks3 reads the token from a file, not an env var.
    with tempfile.NamedTemporaryFile(mode="w", suffix=".tok", delete=False) as f:
        os.chmod(f.name, 0o600)
        f.write(token)

    try:
        sys.exit(subprocess.call(
            ["niks3", "push"] + sys.argv[1:],
            env={
                **os.environ,
                "NIKS3_SERVER_URL": SERVER_URL,
                "NIKS3_AUTH_TOKEN_FILE": f.name,
            },
        ))
    finally:
        os.unlink(f.name)


if __name__ == "__main__":
    main()
