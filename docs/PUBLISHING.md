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
