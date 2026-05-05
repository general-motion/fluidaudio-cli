#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
prefix="/usr/local"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "fluidaudio currently ships prebuilt archives for macOS." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "fluidaudio release archives currently support Apple Silicon Macs." >&2
  exit 1
fi

archive="fluidaudio-aarch64-apple-darwin.tar.gz"
url="https://github.com/general-motion/fluidaudio-cli/releases/download/v${VERSION}/${archive}"
workdir="$(mktemp -d)"

cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

install_command=(install)
if [[ ! -w "${prefix}" ]]; then
  install_command=(sudo install)
fi

echo "Downloading ${url}"
curl -fL "${url}" -o "${workdir}/${archive}"
tar -xzf "${workdir}/${archive}" -C "${workdir}"

"${install_command[@]}" -d "${prefix}/bin"
"${install_command[@]}" "${workdir}/fluidaudio" "${prefix}/bin/fluidaudio"

echo "Installed fluidaudio to ${prefix}/bin/fluidaudio"
