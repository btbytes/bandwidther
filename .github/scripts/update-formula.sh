#!/bin/bash
set -euo pipefail

VERSION="$1"
ZIP_URL="$2"

cat <<EOF
class Bandwidther < Formula
  desc "macOS menu bar app that monitors per-process network bandwidth usage"
  homepage "https://github.com/btbytes/bandwidther"
  url "$ZIP_URL"
  version "$VERSION"
  sha256 "$SHA256"
  license :can_use_with_0_warnings

  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    bin.install "Bandwidther"
  end

  def caveats
    <<~EOS
      Bandwidther is a macOS menu bar app. After installation, run it with:
        open \#{opt_bin}/Bandwidther

      Or launch via Spotlight by searching for "Bandwidther".
    EOS
  end

  test do
    assert_predicate opt_bin/"Bandwidther", :exist?
  end
end
EOF
