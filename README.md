# onxxruntime

Republished ONNX Runtime shared libraries for `linux-x64`, built from source by
[conda-forge](https://github.com/conda-forge/onnxruntime-feedstock) with
telemetry disabled.

The Microsoft `microsoft/onnxruntime` GitHub repository is no longer available,
so this repository provides a stable, pinned, checksummed tarball that can be
fetched with Bazel `http_archive` or used directly.

## What is in the release

`onnxruntime-1.32.0-linux-x64.tar.gz` contains:

- `lib/libonnxruntime.so` and its versioned variants
- all shared library dependencies needed at runtime
  (`libprotobuf`, `libre2`, `libabseil`, `libstdc++`, `libgcc_s`, `libgomp`,
  `libz`, and `_openmp_mutex`)
- `licenses/` with the license texts of the bundled conda-forge packages
- `PROVENANCE` with the exact conda-forge package URLs and sha256 checksums

## Telemetry

The conda-forge recipe builds `onnxruntime-cpp` with `--no_telemetry`, which
sets `onnxruntime_USE_TELEMETRY=OFF`. See
[`recipe/build-cpp.nu`](https://github.com/conda-forge/onnxruntime-feedstock/blob/main/recipe/build-cpp.nu).

## Verifying a release

```sh
sha256sum -c SHA256SUMS
tar -tzf onnxruntime-1.32.0-linux-x64.tar.gz | head
```

The `PROVENANCE` file in the tarball lists every downloaded package and its
sha256. The same list is pinned in `build.sh`.

## Bazel usage

```python
http_archive(
    name = "onnxruntime_prebuilt",
    build_file_content = """
filegroup(
    name = "libs",
    srcs = glob(["lib/*.so*"]),
    visibility = ["//visibility:public"],
)
    """,
    sha256 = "<sha256 of the release tarball>",
    strip_prefix = "onnxruntime-1.32.0-linux-x64",
    url = "https://github.com/teapotovh/onxxruntime/releases/download/v1.32.0/onnxruntime-1.32.0-linux-x64.tar.gz",
)
```

Copy every file from `@onnxruntime_prebuilt//:libs` into the image, not only
`libonnxruntime.so`. The dynamic loader must be able to find the dependency
libraries at runtime. For example, put them all in `/lib` or set
`LD_LIBRARY_PATH` to their directory.

## Rebuilding

`build.sh` downloads the pinned conda-forge packages, verifies their sha256,
extracts the shared libraries, and writes `dist/`:

```sh
./build.sh
```

The GitHub workflow runs the same script on every push to `main` that changes
`build.sh`, then creates or updates the release `v1.32.0` and uploads the
tarball and `SHA256SUMS`.

To upgrade ONNX Runtime, update `ORT_VERSION`, the package URLs, and the
checksums in `build.sh`, then push.
