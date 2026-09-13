# semantic-docs: reproducible platform builds

## Versions, tools and build layout

The glibc installer pins component tag **v0.5.0-insightos.2026.2** at `7544152d4fea8bcf06dfb11d89f642455a7e2742`.
This guide pins the current build-script snapshot at `4824693776b275d29decd1c1e8eda4256a19ee7f`.
To reconstruct another published release, read its `release.json` and select
both `source_commit` and `build_recipe_commit`; a source tag alone may predate
the CI scripts. This recipe reproduces the build steps, not historical archive bytes.

Prerequisites: Linux x86_64, Node.js 22/npm, Python 3, curl, tar and sha256sum. The script downloads checksum-verified Hugo Extended 0.128.2 for Linux amd64.

The release scripts expect **two sibling checkouts**, `automation/` for build
scripts and `source/` for the component. Run these commands from a fresh working
directory (the scripts themselves are not standalone copies):

```bash
REPRO_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/semantic-docs-repro.XXXXXXXX")"
git clone --no-checkout https://github.com/insightos-community/semantic-docs.git "$REPRO_ROOT/automation"
GIT_LFS_SKIP_SMUDGE=1 git -C "$REPRO_ROOT/automation" checkout --detach 4824693776b275d29decd1c1e8eda4256a19ee7f
git clone --no-checkout https://github.com/insightos-community/semantic-docs.git "$REPRO_ROOT/source"
GIT_LFS_SKIP_SMUDGE=1 git -C "$REPRO_ROOT/source" checkout --detach v0.5.0-insightos.2026.2
cd "$REPRO_ROOT/source"
test "$(git rev-parse HEAD)" = 7544152d4fea8bcf06dfb11d89f642455a7e2742
export TARGET_TAG=v0.5.0-insightos.2026.2
export COMPONENT=semantic-docs
export GITHUB_SHA=4824693776b275d29decd1c1e8eda4256a19ee7f
```

## Linux glibc / standard component Release

The executable build entry is [`.github/scripts/build.sh`](.github/scripts/build.sh);
archive validation is [`.github/scripts/package.py`](.github/scripts/package.py).
From `source/` in the layout above:

```bash
bash ../automation/.github/scripts/build.sh
python3 ../automation/.github/scripts/package.py 
(cd .output/release && sha256sum -c SHA256SUMS)
```

Artifacts: `source/.output/release/` (archives/wheels, `release.json`, checksum
inventory and license notices). `release.json` records source and recipe revisions.
The local commands do not publish or overwrite a GitHub Release.

## Linux musl

This component produces pure Python wheels, scripts, static Web/docs or assets
that are reused by the musl installer. Reproduce the component on the standard
build host above; a second musl compilation of those same files is unnecessary.
Native transitive dependencies must still be obtained from the musl lock.
The Hugo executable downloaded by `build.sh` is Linux/glibc amd64. Build the
static site on that host and reuse `public/`; do not run that binary natively on Alpine.

For the complete musl build and offline checks, use the [quick-start musl commands](https://github.com/insightos-community/quick-start/blob/main/README.build.md#linux-musl-x86_64).

## macOS / macosx

Use native Hugo **Extended 0.128.2** and Node.js 22/npm. The Linux download
helper is not a macOS script; with the native `hugo` executable on PATH, run:

```bash
hugo version
npm ci --ignore-scripts
npm run docs:build
```

Output: `public/`. The static site can be served on any of the three platforms.

The complete macOS installer targets Apple Silicon/macOS 15.5+; see the [locked assembly instructions](https://github.com/insightos-community/quick-start/blob/main/README.build.md#macos-apple-silicon).

## GitHub workflow reproduction

The repository’s [CI workflow](.github/workflows/ci.yml) implements the two-checkout
layout. To build a source tag without publishing, create a reproduction branch at the
pinned automation commit. GitHub dispatch expects a branch/tag ref; both tag refs
and default-branch dispatches can enter this workflow’s publishing job. The following
commands require repository write access and use a non-default branch:

```bash
gh auth setup-git
REPRO_BRANCH=reproduce/platform-builds
git -C "$REPRO_ROOT/automation" push origin 4824693776b275d29decd1c1e8eda4256a19ee7f:refs/heads/$REPRO_BRANCH
gh workflow run ci.yml --repo insightos-community/semantic-docs --ref "$REPRO_BRANCH" -f tag=v0.5.0-insightos.2026.2
gh run list --repo insightos-community/semantic-docs --workflow ci.yml --limit 5
# Set REPRO_RUN_ID to the selected run ID.
gh run watch "$REPRO_RUN_ID" --repo insightos-community/semantic-docs --exit-status
gh run download "$REPRO_RUN_ID" --repo insightos-community/semantic-docs --name release-assets --dir downloaded-release
```

## Reproduction evidence

Build in a fresh checkout and a separate output directory for each ABI. Preserve
source commits, compiler/tool versions, dependency locks, package inventories and
test logs. Fixed source revisions and a container digest reproduce the recipe;
unlocked OS packages, runner images, timestamps and build tools can still change
archive bytes. Compare a downloaded release against its published `SHA256SUMS`;
do not expect a local rebuild to have the same digest.

See the [complete installer and repository index](https://github.com/insightos-community/quick-start/blob/main/README.build.md) for assembly order,
platform locks and end-to-end validation. Local build commands do not publish a
Release. Publishing requires repository write access and a new version tag;
existing release tags/assets should not be replaced.
