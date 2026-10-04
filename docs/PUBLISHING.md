# GitHub Pages publication

A completed release publishes the browser build automatically. Source commits do not deploy unfinished versions.

1. Test and audit the source and builds. Keep the Pages workflow, helper and AGENTS.md in every source snapshot.
2. Commit the source and create a draft versioned release.
3. Attach `Reclamation-vMAJOR.MINOR.PATCH-Web.zip`, the source and macOS packages, and `SHA256SUMS.txt`.
4. Publish the release only after all attachments are present. Prereleases also trigger Pages.
5. Check **Actions → Publish game to GitHub Pages** for that tag. Confirm both package and deploy jobs succeed, then check public `version.json` and browser startup.

The workflow downloads the Web build from this repository's exact release. It validates the archive checksum, source/version provenance, WebAssembly header and payload sizes. Only generated static runtime files, build provenance and licenses are deployed. It never executes scripts from the ZIP. Runtime files retain their relative names under a version-specific directory; the project root opens that version automatically.

The first Pages version is v0.8.0. To retry an existing published version, use the workflow's **Run workflow** control with its exact tag. It does not rebuild or change release assets. The workflow only uses GitHub's short-lived built-in token; no personal token or repository secret is required.

## Export requirements

Use Godot's single-threaded Web export and disable PWA/service workers. GitHub Pages cannot be configured with arbitrary COOP/COEP headers. Single-threaded export avoids requiring those headers. Leave `index.html`, engine JS/WASM, PCK and worklets together. Browser storage and audio still depend on browser support and normal user interaction; perform real browser testing.

## References

- [GitHub custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

## Legacy save boundary

v0.9.0 starts save schema 2 and does not migrate v0.8 saves. The Pages artifact keeps the exact v0.8.0 runtime at `releases/v0.8.0/` while the root opens the current release. Its released ZIP checksum, source checksum and commit are pinned in the helper. This preserves the known legacy URL and bytes; it is not a claim that IndexedDB saves are isolated between versions. Do not clear old browser storage as part of deployment.

Only this explicit compatibility boundary is retained, rather than accumulating every past release. Packaging fails above 900 MiB. For offline package validation after v0.8, supply `--legacy-assets-dir` pointing to the verified v0.8.0 Web ZIP and checksums. Changing or removing this boundary is a separate compatibility decision.
