#!/bin/bash
set -euo pipefail

VERSION="$1"
ZIP_URL="$2"

cat <<EOF
cask "bandwidther" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$ZIP_URL"
  name "Bandwidther"
  desc "macOS menu bar app that monitors per-process network bandwidth usage"
  homepage "https://github.com/btbytes/bandwidther"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Bandwidther.app"
end
EOF
