# claude-notifier

Send macOS notifications with action buttons from the command line.

## Requirements

- macOS 11.0 (Big Sur) or later
- Swift 5.7+

## Installation

### Homebrew (Recommended)

```bash
brew tap kusumotoa/tap
brew install --cask --no-quarantine claude-notifier
```

> **Note:** The `--no-quarantine` flag prevents Gatekeeper warnings since this app is not signed with an Apple Developer ID.

If you already installed without `--no-quarantine` and see a Gatekeeper warning:

```bash
xattr -d com.apple.quarantine /Applications/claude-notifier.app
```

### Manual Installation

```bash
git clone https://github.com/kusumotoa/claude-notifier.git
cd claude-notifier
make install
```

## Usage

```bash
# Basic notification
claude-notifier -message "Hello World"

# With action buttons
claude-notifier -message "Deploy?" -actions "Yes,No" -timeout 30

# With sound
claude-notifier -message "Task completed" -sound default

# Permission prompt style
claude-notifier -message "Allow this action?" -actions "Allow,Deny" -title "Claude Code"

# Pipe from stdin
echo "Build finished" | claude-notifier -sound default

# JSON output for scripting
claude-notifier -message "Continue?" -actions "Yes,No" -json
```

## Options

| Option | Description |
|--------|-------------|
| `-message VALUE` | The message body of the notification |
| `-title VALUE` | The title (default: Terminal) |
| `-subtitle VALUE` | The subtitle |
| `-actions VAL1,VAL2` | Action buttons (comma-separated) |
| `-closeLabel VALUE` | Close button label (default: Close) |
| `-dropdownLabel VALUE` | Dropdown label for multiple actions |
| `-timeout NUMBER` | Auto-close after NUMBER seconds |
| `-sound NAME` | Play sound ('default' for system default) |
| `-json` | Output result as JSON |
| `-reply` | Show reply text field |
| `-group ID` | Group notifications by ID |
| `-remove ID` | Remove notifications (use 'ALL' for all) |
| `-list ID` | List notifications |
| `-help` | Show help |

## Output

The program outputs the user's action to stdout:

| Output | Meaning |
|--------|---------|
| `@TIMEOUT` | Notification timed out |
| `@CLOSED` | User clicked close button |
| `@CONTENTCLICKED` | User clicked notification body |
| `<action>` | The action button clicked |
| `<text>` | User's reply text (with -reply) |

## Example: Shell Script Integration

```bash
#!/bin/bash

ANSWER=$(claude-notifier -message "Start deployment?" \
    -actions "Yes,No" \
    -title "Deploy" \
    -timeout 30)

case $ANSWER in
    "Yes")
        echo "Starting deployment..."
        ./deploy.sh
        ;;
    "No"|"@CLOSED")
        echo "Deployment cancelled"
        ;;
    "@TIMEOUT")
        echo "No response, skipping"
        ;;
esac
```

## Example: Claude Code Hook Integration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/permission-dialog.sh"
          }
        ]
      }
    ]
  }
}
```

## Building from Source

```bash
# Build only
make build

# Create .app bundle
make bundle

# Create release zip
make release

# Clean
make clean
```

## License

MIT License
