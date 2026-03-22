# ClaudeUsageBar

A macOS menu bar app that displays your Claude Code usage at a glance — session rate limits, weekly quotas, and reset times.

<!-- Add a screenshot here: ![ClaudeUsageBar Screenshot](screenshots/screenshot.png) -->

## What it shows

- **Session usage (5h window):** Percentage of your current 5-hour rate limit consumed
- **Weekly usage (7d window):** Percentage of your 7-day rate limit consumed
- **Reset times:** When each limit resets (relative + absolute time)
- **Menu bar icon:** Shows the highest current usage percentage

The progress bars change color based on utilization: blue (normal), yellow (>50%), red (>80%).

## How it works

1. **Claude Code's `statusLine` hook** sends rate limit data (from API response headers) to a configured shell command every time it processes a message.
2. **The hook script** (`usage-cache-hook.sh`) extracts `rate_limits` from the JSON input and writes them to `~/.claude/usage_cache.json`.
3. **The menu bar app** reads this cache file on demand (when you click the menu bar icon) and displays the usage data.
4. **Data refreshes** every time Claude Code processes a message — no polling, no API keys needed.

```
Claude Code API response
        │
        ▼
statusLine hook (stdin JSON)
        │
        ▼
usage-cache-hook.sh
        │
        ▼
~/.claude/usage_cache.json
        │
        ▼
ClaudeUsageBar (reads on click)
```

## Prerequisites

- **macOS 13** (Ventura) or later
- **Xcode Command Line Tools** (for the Swift compiler): `xcode-select --install`
- **jq** (JSON processor): `brew install jq`
- **Claude Code** with an active subscription (Pro or Max) — the app reads data produced by Claude Code

## Installation

### Quick install

```bash
git clone https://github.com/tonistation/claude_code_usage_info_task_bar.git
cd claude_code_usage_info_task_bar
bash install.sh
```

The install script will:
1. Check that all prerequisites are met
2. Copy the hook script to `~/.claude/usage-cache-hook.sh`
3. Add the `statusLine` hook configuration to `~/.claude/settings.json` (merges safely, does not overwrite existing settings)
4. Build the Swift app in release mode
5. Create the `.app` bundle and install it to `~/Applications/`

### Manual install

If you prefer to do it step by step:

**1. Copy the hook script:**

```bash
cp hooks/usage-cache-hook.sh ~/.claude/usage-cache-hook.sh
chmod +x ~/.claude/usage-cache-hook.sh
```

**2. Configure Claude Code settings:**

Add the following to `~/.claude/settings.json` (create the file if it doesn't exist):

```json
{
  "hooks": {
    "statusLine": [
      {
        "command": "bash ~/.claude/usage-cache-hook.sh"
      }
    ]
  }
}
```

If you already have other settings in that file, just add the `hooks.statusLine` entry — don't overwrite the rest.

**3. Build the app:**

```bash
swift build -c release
bash build.sh
```

**4. Launch:**

```bash
open ~/Applications/ClaudeUsageBar.app
```

### Launch at login (optional)

To have ClaudeUsageBar start automatically:

1. Open **System Settings** > **General** > **Login Items**
2. Click **+** and select `~/Applications/ClaudeUsageBar.app`

## Usage

1. Start a Claude Code session and send at least one message (this triggers the hook to write usage data).
2. Look for the chart icon with a percentage in your macOS menu bar.
3. Click it to see the full breakdown: session usage, weekly usage, and reset times.
4. Click **Refresh** to re-read the cache file at any time.

If the app shows `---%`, it means no usage data has been written yet — just use Claude Code normally and the data will appear.

## Uninstallation

**Remove the app:**

```bash
rm -rf ~/Applications/ClaudeUsageBar.app
```

**Remove the hook script:**

```bash
rm ~/.claude/usage-cache-hook.sh
rm -f ~/.claude/usage_cache.json
```

**Remove the hook from Claude Code settings:**

Edit `~/.claude/settings.json` and remove the `statusLine` entry that references `usage-cache-hook.sh`. If it was the only hook, you can remove the entire `hooks` section.

## Architecture

```
.
├── Package.swift                          # Swift Package Manager manifest
├── Sources/ClaudeUsageBar/
│   ├── App.swift                          # App entry point (MenuBarExtra)
│   ├── Models/
│   │   └── UsageLimit.swift               # Data models + JSON decoding
│   ├── Services/
│   │   ├── UsageAPIClient.swift           # Reads and parses the cache file
│   │   └── KeychainService.swift          # Placeholder (not used)
│   ├── ViewModels/
│   │   └── UsageViewModel.swift           # State management + refresh logic
│   └── Views/
│       ├── MenuBarView.swift              # Main popover UI
│       └── UsageBarView.swift             # Reusable progress bar component
├── hooks/
│   └── usage-cache-hook.sh                # Claude Code statusLine hook script
├── build.sh                               # Builds .app bundle + installs
└── install.sh                             # Full automated installer
```

## Cache file format

The hook writes `~/.claude/usage_cache.json` with this structure:

```json
{
  "rate_limits": {
    "five_hour": {
      "used_percentage": 12.5,
      "resets_at": 1742688000
    },
    "seven_day": {
      "used_percentage": 5.2,
      "resets_at": 1743120000
    }
  },
  "updated_at": 1742670000,
  "session_id": "abc123",
  "model": {
    "id": "claude-sonnet-4-20250514",
    "display_name": "Claude Sonnet 4"
  }
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.
