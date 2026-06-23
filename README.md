# TimeBox · 时间盒子 ⏱

A minimalist time-boxing timer for macOS. Stay focused, one 10-minute block at a time.

> Break your day into 10-minute blocks. Set an intention, work on it, punch in when done,
> and move to the next block. No complex setup — just a floating timer that stays on top.

## Features

- **10-minute blocks** — Short enough to stay urgent, long enough to get into flow.
- **Floating window** — Always on top. Stays visible while you work.
- **📋 Todo panel** — Free-form editable text view. Enter = newline, ⌘+Enter = copy line to task input + auto-delete. Auto-saved across sessions.
- **Daily note sync** — Punch entries are automatically written to your daily markdown note (`## M.D` section, `HH:MM task` format).
- **Native macOS app** — Objective-C. Lightweight, zero Electron overhead.
- **HTML/Web version** — Runs in browser or WKWebView. Same timer, same flow.
- **Swift version** — Alternative implementation using Swift + WKWebView.

## Screenshot

```
┌──────────────────────────────────┐
│    10:00                         │
│  08:30 – 08:40 · 第 1 块  0 轮打卡│
│  ████████████░░░░░░░░░░░░░░░░░░  │
│                                  │
│  🎯 写邮件给客户确认方案            │
│  ┌─────────────────┐ [📋] [✓]  │  ← 📋 toggles todo panel
│  │ 要做什么？        │          │
│  └─────────────────┘          │
│  [⏸ 暂停] [⏭ 跳过] [⟳ 重置]    │
│                                  │
│  │📋 代办 (3)                   │  ← expandable todo panel
│  │· 写周报                      │
│  │· 整理报销                     │
│  │· 回复客户邮件                 │
│  │[添加代办…]           [＋]    │
│                                  │
│  📋 今天记录 ▾                   │
│  🎯 写邮件 · 08:25               │
│  🎯 看文档 · 08:15               │
└──────────────────────────────────┘
```

## Getting Started

### Native App (Objective-C)

**Build & run directly (recommended for development):**

```bash
# Compile
clang -fobjc-arc -framework Cocoa -o TimeBoxNative TimeBoxApp.m

# Run
./TimeBoxNative
```

**Desktop .app bundle (for daily use):**

The `TimeBox.app` on the Desktop uses a shell script that runs the compiled `TimeBoxNative` from the project directory:

```bash
# After compiling, just double-click TimeBox.app on Desktop
# Or launch from terminal:
open ~/Desktop/TimeBox.app
```

> ⚠️ **Important**: The `.app` bundle's executable **must** be a shell script (not the binary directly).
> macOS sandbox/TCC blocks file access to `~/Documents/` when the binary runs from inside the `.app`.
> The shell script simply execs the binary from the project directory, which has full file permissions.

### HTML/Web Version

```bash
# Serve locally
python3 serve.py

# Open in browser
open http://localhost:8765
```

### Swift Package

```bash
swift run
```

## Daily Note Sync

TimeBox logs your punches to a daily markdown note at:

```
<NOTE_DIR>/YYYY-MM.md
```

Entries are written under the `## M.D` section (e.g. `## 6.23`) in `HH:MM task` format:

```markdown
## Other stuff

## 6.23
09:30 写邮件给客户确认方案

## 6.22
16:00 代码审查
```

### Configuration

| Variable   | Default                                    | Description                     |
|-----------|--------------------------------------------|---------------------------------|
| `NOTE_DIR` | `~/Documents/Notes/Today/` (configurable ⚙️) | Directory for daily note files  |

Override via environment variable, or click the ⚙️ button in the app to set via file picker:

```bash
export NOTE_DIR=~/Documents/Notes/Journal/
./TimeBoxNative
```

## 📋 Todo Panel

The todo panel is a simple editable text view that toggles with the 📋 button next to the task input.

- **Enter** — Insert newline
- **⌘+Enter** — Copy current line to task input, then delete the line from the todo list
- **Auto-save** — Content is saved to `NSUserDefaults` when the panel is closed
- **Persistence** — Todos survive app restarts

## Project Structure

```
TimeBox/
├── TimeBoxApp.m          # Native macOS app (Objective-C) — main file
├── serve.py              # HTTP server for HTML version (punch API + note sync)
├── timebox.html          # HTML/JS timer (runs in browser or WKWebView)
├── TimeBoxWeb.swift      # Swift wrapper for HTML version
├── Sources/TimeBox/      # Swift package source
│   ├── TimeBox.swift     # Native Swift implementation
│   └── main.swift        # Entry point
├── Package.swift         # Swift Package Manager config
├── TimeBoxNative         # Compiled ObjC binary (gitignored)
└── .env.example          # Environment configuration template
```

## License

MIT
