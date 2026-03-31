# Bandwidther

Bandwidther is a native macOS menu bar app for monitoring per-process network bandwidth in real time.

> [!NOTE]
> This app was vibe coded using Claude Opus 4.6 and GPT-5.4. I do not have deep knowledge of macOS networking or SwiftUI such that I can confidently evaluate the end result.

![Screenshot of Bandwidther macOS app showing two columns: left side displays overall download/upload speeds, a bandwidth graph over the last 60 seconds, cumulative totals, internet and LAN connection counts, and internet destinations; right side shows per-process bandwidth usage sorted by rate with processes like nsurlsessiond, apsd, rapportd, mDNSResponder, Dropbox, and others listed with their individual download/upload speeds and progress bars.](https://github.com/btbytes/bandwidther/raw/main/screenshot.png)

## Features

- Live per-process download and upload rates from `nettop`
- Sortable process list by rate, download, upload, total bytes, or name
- Menu bar popover with overall rates, cumulative totals, and a 60-sample sparkline
- Internet vs LAN/local connection summaries grouped by process
- Internet destination list with best-effort reverse DNS lookup
- Simple app visibility settings for Dock and Cmd-Tab app switcher presence

## Requirements

- macOS 14+
- Xcode command line tools (`xcode-select --install`)

## Install

### Homebrew

```bash
brew tap btbytes/brew
brew install --cask bandwidther
```

### Manual download

Download the latest release from the [Releases page](https://github.com/btbytes/bandwidther/releases).

## Build from source

This repo builds directly with the included `Makefile`; there is no Xcode project required.

```bash
git clone https://github.com/btbytes/bandwidther
cd bandwidther
make
open Bandwidther.app
```

Or build and launch in one step:

```bash
make run
```

## How it works

Bandwidther uses built-in macOS command-line tools rather than packet capture or private APIs.

- Per-process bandwidth comes from `nettop` in delta mode. The app requests two samples and uses the second sample as the current per-process download and upload rate.
- The cumulative totals shown in the UI come from the baseline `nettop` sample. They are totals reported by `nettop`, not counters maintained independently by the app.
- Connection summaries come from `lsof -n -P -iTCP -iUDP`. The app parses socket entries, attributes them to processes, and classifies remote endpoints as internet or LAN/local using address heuristics.
- Reverse DNS uses `getnameinfo`, so hostnames are best effort and some destinations may remain as raw IP addresses.

## Limitations

- The connection panels are socket snapshots, not packet-level accounting.
- LAN vs internet classification is heuristic. Private IPv4, loopback, link-local IPv6, unique-local IPv6, carrier-grade NAT space, and benchmark ranges are treated as local.
- The destination list currently focuses on internet destinations in the main UI.
- If `nettop` or `lsof` is unavailable or blocked by the system, Bandwidther may show incomplete data. `nettop` failures are surfaced in the UI.

## Settings

Bandwidther includes a small Settings window with toggles for:

- showing the app in the Dock
- showing the app in the Cmd-Tab app switcher
- launching the app at login
