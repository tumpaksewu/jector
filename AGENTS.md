# Jector

Alex owns this. Reply in the language of the user's last message; keep updates concise.

- Prefer explicit, modular code; keep authored files around 200 lines or less.
- Fix root causes. Remove superseded implementations rather than adding compatibility layers.
- Verify behavior; never infer successful playback from successful command delivery.
- Ignore CLAUDE.md. Use uv for Python tooling.
- `project.yml` is the source of truth for the generated Xcode project.
- Display/product name: Jector. The stable bundle ID and Keychain tag preserve the existing installation's data and authorized ADB identity; do not change casually.
- Personal signing belongs in ignored `Signing.xcconfig`.
- Never commit model weights, runtime binaries, device reports, screenshots of personal libraries, signing material or build output.
- Model-generated commands pass strict validation and execute through fixed mappings. No raw model-generated shell.
- Projector integration is currently validated only for Formovie S5/Peppa.
- Match tests to changes; new app routes require real EN/RU projector verification.

## Checks

`swift test --package-path Core`

`./scripts/build-unsigned.sh`

The unsigned IPA script verifies device platform, bundle branding, absence of weights, all Mach-O signatures and ZIP integrity. Release assets must be re-signed before installation. Keep build artifacts in ignored `work/` or `dist/` and clean task scratch when finished.
