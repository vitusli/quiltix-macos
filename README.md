# quiltix-macos

Build [QuiltiX](https://github.com/PrismPipeline/QuiltiX) on macOS Apple Silicon.

This repository contains a self-contained `build.sh` that:

- clones QuiltiX and OpenUSD into local build directories
- checks out pinned commits for deterministic rebuilds
- creates an isolated Python 3.11 virtual environment
- builds OpenUSD with `usdview` and `MaterialX` support (needed by QuiltiX)
- validates imports and creates launcher scripts

## Versions used

- **OpenUSD:** `0.26.8` (from pinned commit `3e3890068e17f0e31dc34f906f7f1fa1037dd7da`)
- **MaterialX (Python package):** `1.39.5` (explicitly installed/pinned in `build.sh`)
- **QuiltiX:** pinned commit `c83f929b284b38d623fb0c9697b00a6d9606a5d8`

## Build from source

```bash
git clone https://github.com/vitusli/quiltix-macos.git
cd quiltix-macos
./build.sh
```

Then launch:

```bash
./build/run.sh
```

## Requirements

- macOS on Apple Silicon
- Xcode command-line tools (`xcode-select --install`)
- [Homebrew](https://brew.sh)
- `python@3.11` and `cmake`
- ~30+ GB free disk space
- Internet connection (clones repositories and downloads dependencies)

Install prerequisites:

```bash
brew install python@3.11 cmake
```

## Script options

```bash
./build.sh --help
./build.sh --python /opt/homebrew/bin/python3.11
./build.sh --skip-openusd-build
```

## Project structure

```text
quiltix-macos/
  build.sh          # Main reproducible build script
  source/           # Cloned QuiltiX source (ignored)
  deps/             # Cloned OpenUSD source + install (ignored)
  build/            # venv + launch helpers (ignored)
```

After building:

```text
  build/env.sh      # Environment exports for runtime
  build/run.sh      # Starts QuiltiX with the right env
```

## Reproducibility notes

The script pins upstream commits directly in `build.sh`:

- QuiltiX commit: `c83f929b284b38d623fb0c9697b00a6d9606a5d8`
- OpenUSD commit: `3e3890068e17f0e31dc34f906f7f1fa1037dd7da`
- MaterialX Python package: `1.39.5`

## License

This repository's own files (`build.sh`, docs, helper scripts) are licensed under Apache-2.0.

Upstream projects are not redistributed here. They remain under their original licenses:

- QuiltiX: Apache-2.0
- OpenUSD: Modified Apache 2.0

When using binaries produced by this script, ensure compliance with all upstream licenses and notices.
