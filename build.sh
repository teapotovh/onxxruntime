#!/usr/bin/env bash
#
# Build the release tarball for linux-x64 from the verified conda-forge
# packages. Every package is pinned by URL and sha256.
#
# The tarball contains the shared libraries needed to dlopen libonnxruntime.so
# and the licenses of the bundled packages.
set -euo pipefail

ORT_VERSION="1.32.0"
RELEASE_TAG="v${ORT_VERSION}"
NAME="onnxruntime-${ORT_VERSION}-linux-x64"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${ROOT}/work"
DIST="${ROOT}/dist"
OUT="${DIST}/${NAME}"

# name=url sha256
# The onnxruntime-cpp package is built by conda-forge from the v1.32.0 source
# with --no_telemetry, which sets onnxruntime_USE_TELEMETRY=OFF.
PACKAGES=(
  "onnxruntime-cpp=https://conda.anaconda.org/conda-forge/linux-64/onnxruntime-cpp-1.32.0-h49c692b_0_cpu.conda eee5128565fef980d6848614db182071f500faf8f2c22133a41d17c56780de7a"
  "libabseil=https://conda.anaconda.org/conda-forge/linux-64/libabseil-20260817.0-cxx17_hbb87c76_2.conda 478f0a05d1310dbf9e9a1887aeb482ebc0cb8fbe4ca9e206aec11479c0da89f9"
  "libgcc=https://conda.anaconda.org/conda-forge/linux-64/libgcc-16.2.0-ha9f2e26_7.conda e031634c3a928f9594eba868bc46ef5230d6571a364a0c63215b06c4563bfcea"
  "libgomp=https://conda.anaconda.org/conda-forge/linux-64/libgomp-16.2.0-he0feb66_7.conda 92a0bb350c7be6a4eedcb4e111c60aefd176018e6b1c009a6e025dbe9bbcd758"
  "libprotobuf=https://conda.anaconda.org/conda-forge/linux-64/libprotobuf-7.35.1-h8a00109_4.conda 132df0c122cc211ad51a4622036a2a31e4751fcc3702d3663d95ae27f98f9ea7"
  "libre2-11=https://conda.anaconda.org/conda-forge/linux-64/libre2-11-2025.11.05-h02ca46f_4.conda 0c49508a9525f89e9195155e106ae8c9fb57ddf46e5111f98d7f3227976c6a15"
  "libstdcxx=https://conda.anaconda.org/conda-forge/linux-64/libstdcxx-16.2.0-h934c35e_7.conda fa7018298629fc429971fffd6ecba3d27a7b02e4e890d6a93ea01ffebe8cb745"
  "libzlib=https://conda.anaconda.org/conda-forge/linux-64/libzlib-1.3.2-h25fd6f3_3.conda eb8a0db0aa570124f7d2a93d7c7f596e3390df5e047818d873baad32985fc736"
  "_openmp_mutex=https://conda.anaconda.org/conda-forge/linux-64/_openmp_mutex-4.5-20_gnu.conda 1dd3fffd892081df9726d7eb7e0dea6198962ba775bd88842135a4ddb4deb3c9"
)

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

need curl
need sha256sum
need tar
need unzip

rm -rf "${WORK}" "${DIST}"
mkdir -p "${WORK}" "${OUT}/lib" "${OUT}/licenses"

PROVENANCE="${OUT}/PROVENANCE"
{
  echo "ONNX Runtime ${ORT_VERSION} shared libraries for linux-x64"
  echo
  echo "Source: conda-forge onnxruntime-feedstock"
  echo "https://github.com/conda-forge/onnxruntime-feedstock"
  echo
  echo "The conda-forge recipe builds onnxruntime-cpp with --no_telemetry,"
  echo "which sets onnxruntime_USE_TELEMETRY=OFF."
  echo
  echo "Packages:"
} >"${PROVENANCE}"

for entry in "${PACKAGES[@]}"; do
  name="${entry%%=*}"
  rest="${entry#*=}"
  read -r url sha <<<"${rest}"

  archive="${WORK}/${name}.conda"
  echo "Fetching ${name}"
  curl -fsSL "${url}" -o "${archive}"
  printf '%s  %s\n' "${sha}" "${archive}" | sha256sum -c -

  mkdir -p "${WORK}/${name}"
  unzip -q "${archive}" -d "${WORK}/${name}"
  (
    cd "${WORK}/${name}"
    tar --zstd -xf pkg-*.tar.zst
    tar --zstd -xf info-*.tar.zst
  )

  if [ -d "${WORK}/${name}/lib" ]; then
    cp -a "${WORK}/${name}/lib/." "${OUT}/lib/"
  fi

  if [ -d "${WORK}/${name}/info/licenses" ]; then
    mkdir -p "${OUT}/licenses/${name}"
    cp -a "${WORK}/${name}/info/licenses/." "${OUT}/licenses/${name}/"
  fi

  printf '%s %s\n' "${name}" "${url} ${sha}" >>"${PROVENANCE}"
done

# Keep only shared libraries; static archives are not used at runtime.
find "${OUT}/lib" -type f -name '*.a' -delete

tar -C "${DIST}" -czf "${DIST}/${NAME}.tar.gz" "${NAME}"
(
  cd "${DIST}"
  sha256sum "${NAME}.tar.gz" >SHA256SUMS
)
printf '%s\n' "${RELEASE_TAG}" >"${DIST}/tag"

echo
echo "Built ${DIST}/${NAME}.tar.gz"
cat "${DIST}/SHA256SUMS"
