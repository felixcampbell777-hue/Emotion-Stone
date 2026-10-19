# Portable setup and checks

Run from the checkout root after `git lfs pull` completes. Python 3 and Git LFS are required for tooling; ordinary editor play does not need Blender.

On macOS or Linux:

```sh
python3 tools/bootstrap_runtime.py
python3 tools/check_checkout.py
./tools/platform.sh validate
./tools/platform.sh inspect-swamp
```

Windows retains `py -3 tools/bootstrap_runtime.py` and `tools\platform.cmd`. Bootstrap pins Godot 4.5.1 standard, verifies downloaded Godot archives against upstream release SHA-256 digests and records machine-local paths in ignored `tools/toolchain.local.json`. Validation/image Python dependencies, including transitive versions, are pinned in `tools/requirements-runtime.txt`. It supports universal macOS, Linux x86_64/ARM64 and Windows x64 editor archives. Linux ARM64 server exports are not yet verified. Export templates include Windows and Linux x86_64. `--skip-templates` installs only the editor. Windows bootstrap also installs Blender 4.5.3; macOS/Linux install it only with `--with-blender`. Blender archives are verified against the upstream SHA-256 manifest, then extracted into the ignored cache. Art authoring alone needs Blender.

The tool cache must be on an executable filesystem. A `noexec` home/cache mount cannot run the engine; choose an executable location with `WORLD_RISE_TOOL_CACHE`. Docker tmpfs caches require an explicit `exec` mount option for developer-bootstrap tests. Bootstrap runs the pinned engine version check before reporting success. Caches default to `~/.cache/comic-art-platform`; `WORLD_RISE_TOOL_CACHE` overrides that location. `WORLD_RISE_PYTHON` selects Python for the shell wrapper; rerun bootstrap with that interpreter when changing it. By default the CLI reuses the bootstrap interpreter recorded locally so native dependency wheels match its Python ABI, including when Windows has a different bundled Python. Neither absolute tool paths nor downloads belong in Git.

`check-script scripts/path_to_checks.gd` runs a focused fixture with disposable userdata; add `--render` for native rendering fixtures. Run `verify-appearance` for the focused profile/material/iris and geometry suites after a coordinated import. Existing fixture/capture commands do likewise. Windows APPDATA/LOCALAPPDATA, Linux XDG folders and macOS HOME/Library are isolated for the subprocess and removed when it exits or times out. Never launch fixture scripts directly against ordinary user data. The wrapper writes one current compact result/failure log per named feature and a last-completed summary; `check_checkout.py` is read-only.

For a development editor use the engine path from the local toolchain with `--editor --path game`. Wait for LFS before the first import. That editor launch uses ordinary user data; do not use it for save-mutating fixtures. Windows packaging/capture commands produce Windows executables and need Windows to execute them; portable source fixtures work on the host engine. Full gated asset builds still require pinned Blender and the model approval gates.

Capture output is owned by its feature/view under `output/verification/draft-render/<view>` or `current-render/<view>`; source checks retain their current compact result. There is no global directory pruning after a test: that can delete another active capture or user draft. Import/native capture windows must still be coordinated by the verification owner. Replace only evidence owned by the current feature; never clean user-authored map fragments/drafts.

Desktop candidate packaging uses `./tools/platform.sh export-client --target macos` or `--target windows` and writes ignored `output/clients/<target>/v<VERSION>/` without replacing the selected Windows release. These commands validate content and package resources; they are not the gated asset/gameplay release build. `--skip-tests` explicitly skips content validation. macOS candidates use the pinned universal template and an ad-hoc signature, optional voice microphone usage text/audio-input entitlement and bundled runtime library notices; they are not notarized distribution releases. Windows execution must be verified on Windows. Candidate manifests record all runtime source groups before/after export and output hashes. A changed source fingerprint requires another export after the shared source freeze.

macOS signing/template behavior follows the pinned engine's [macOS export guidance](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_macos.html). An ad-hoc candidate is for local verification; notarized public distribution needs a separately configured developer identity and distribution acceptance.
