# Release and publication

- Keep game source, assets, documentation and tests in this repository. Never commit credentials, local workspace reports, editor caches or user conversation data.
- Each completed version must have a tagged GitHub release with the audited source, macOS and Web packages and `SHA256SUMS.txt`. Upload all assets before publishing the release.
- Publishing a release runs `.github/workflows/pages.yml` automatically and deploys the checksum-verified Web package to this repository's GitHub Pages site. This applies to prereleases too. A source commit alone does not deploy unfinished work.
- Preserve this file, `.github/workflows/pages.yml`, `scripts/prepare_pages.py` and `docs/PUBLISHING.md` when assembling a new source snapshot. Never replace the repository tree with a snapshot that silently deletes publishing infrastructure.
- Web ZIP naming: `Reclamation-vMAJOR.MINOR.PATCH-Web.zip`; include exact SHA256 in `SHA256SUMS.txt`. Runtime `index.html`, versioned engine JS/PCK/WASM and `BUILD-PROVENANCE.json` are at archive root. The executable basename in GODOT_CONFIG must match adjacent files (for example `reclamation-0.8.0`). Provenance version and main.gd checksum must match the tag.
- Export Web single-threaded with PWA disabled; preserve all generated relative runtime filenames. Do not add a custom domain, PAT, account token or other persistent credentials.
- Verify the workflow completed successfully for the exact tag, the public version.json identifies that commit/version, and the browser actually boots the game. Passing packaging checks alone is not a runtime test. Report unverified platform behavior accurately.

- Before a formal release, gameplay, UI and save-schema compatibility are not release requirements. Breaking changes are allowed; do not add migration or legacy-retention work as a release gate unless explicitly requested. This does not authorize deletion of unrelated data. The existing publishing helper may retain a historical runtime, but compatibility must not delay current game improvements.

# Runtime Japanese font

Before export, run `python tools/build_runtime_font.py --source . --output assets/ReclamationUIJP-Regular.otf --check` with fontTools 4.61.1. Regenerate after adding UI text and verify rendered UI. Keep the full original collection and license in source, exclude assets/Japanese.ttc from runtime exports, and include licenses/*. Introducing free text, new languages or remote text requires a coverage review; this finite subset is not a general Japanese text font.
