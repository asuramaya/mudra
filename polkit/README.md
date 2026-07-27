# polkit gate for the desk

`com.asuramaya.mudra.policy` registers one action, `com.asuramaya.mudra.open-desk`,
`allow_active=auth_self_keep`. Once installed, opening the desk's token URL for
the first time (minting a new session cookie) triggers the SAME
fingerprint/password prompt as any other polkit-gated admin action on this
desktop, on top of the existing URL token — not instead of it. An
already-cookied browser is never re-prompted; `/api/status` and `/api/log`
poll freely.

Install (needs root — the action file lives in a system directory, mudra
never touches it itself):

```sh
make install-polkit
```

which is exactly:

```sh
sudo install -m644 polkit/com.asuramaya.mudra.policy /usr/share/polkit-1/actions/
systemctl --user restart mudra
```

Until it's installed, `mudra serve` degrades to the old token-only gate and
logs a loud one-line warning — it never locks you out of a fresh checkout.

Enroll a fingerprint first (`fprintd-enroll`) if you want the prompt to
actually be a fingerprint rather than falling back to your login password —
polkit uses whatever the desktop's registered agent offers.
