# Steinbock on Apple Silicon (M1/M2/M4) — Native ARM64 Setup

Steinbock's official Docker image (`ghcr.io/bodenmillergroup/steinbock`) is compiled for `linux/amd64`. On Apple Silicon, running it through Rosetta emulation works for most of the pipeline — but **DeepCell/Mesmer segmentation fails** because the TensorFlow library inside the image was compiled with AVX instructions (Advanced Vector Extensions), a CPU feature specific to x86 processors that Rosetta does not emulate. The error looks like this:

```
The TensorFlow library was compiled to use AVX instructions,
but these aren't available on your machine.
```

This repository provides an installer that builds Steinbock from source as a **native ARM64 Docker image**, allowing the full pipeline including DeepCell segmentation to run on M1, M2, and M4 Macs.

---

## Requirements

- Apple Silicon Mac (M1, M2, or M4)
- Docker Desktop (latest) — with **Rosetta emulation enabled**: Settings → General → "Use Rosetta for x86/amd64 emulation on Apple Silicon"
- Git
- ~15–20 minutes and ~5 GB disk space for the initial build

---

## Installation

```bash
bash install_steinbock_arm64.sh
```

This will clone the Steinbock GitHub repository, build a native ARM64 image tagged `steinbock-arm64`, sanity-check the CLI, and add a convenience alias to `~/.zshrc`:

```bash
alias steinbock='docker run --rm --entrypoint steinbock -v "$PWD":/data steinbock-arm64'
```

Open a new terminal after the build completes, then verify:

```bash
steinbock --version
```

For full pipeline usage, refer to the [official Steinbock documentation](https://bodenmillergroup.github.io/steinbock).

---

## Critical: panel.csv deepcell column

The most common segmentation failure on any platform — and especially easy to hit when panel.csv is auto-generated — is having `0` in the `deepcell` column for non-segmentation channels.

Steinbock reads the `deepcell` column and aggregates channels by their unique non-NaN values. With `0`, `1`, and `2` all present, it finds **three** channel groups instead of two and raises:

```
Invalid number of aggregated channels: expected 2, got 3
```

**The fix:** leave non-segmentation rows **empty** in the `deepcell` column. Empty cells are read as `NaN` and skipped. Do not use `0`.

| deepcell value | meaning |
|---|---|
| `1` | nuclear channel (e.g. Ir191, Ir193) |
| `2` | cytoplasmic / membrane channel (e.g. CD45, CD31) |
| *(empty)* | not used for segmentation |

Example:
```
channel,name,keep,ilastik,deepcell,cellpose
Ir191,191Ir,1,48,1,
Dy162,CD45,1,32,2,
Nd142,CD20,1,13,,
```

If your panel.csv was auto-generated and has `0` in the deepcell column, fix it with:

```python
python3 -c "
lines = []
with open('panel.csv') as f:
    for line in f:
        parts = line.strip().split(',')
        if len(parts) >= 5 and parts[4] == '0':
            parts[4] = ''
        lines.append(','.join(parts) + '\n')
with open('panel.csv', 'w') as f:
    f.writelines(lines)
"
```

---

## References

- [Steinbock documentation](https://bodenmillergroup.github.io/steinbock)
- [Steinbock GitHub](https://github.com/BodenmillerGroup/steinbock)
- [DeepCell / Mesmer](https://github.com/vanvalenlab/deepcell-tf)
- [IMmuneCite workflow — Barbetta et al., Sci Rep 15, 9394 (2025)](https://doi.org/10.1038/s41598-025-93379-w)
