# TimeBox · 时间盒子 ⏱

A minimalist time-boxing timer for macOS. Stay focused, one 10-minute block at a time.

> TimeBox is a personal productivity tool that helps you break your day into 10-minute
> blocks. Set an intention, work on it, punch in when done, and move to the next block.
> No complex setup — just a floating timer that stays on top of everything.

## Features

- **10-minute blocks** — The classic time-boxing interval. Short enough to stay urgent, long enough to get into flow.
- **Floating window** — Always on top. Stays visible while you work in other apps.
- **Daily note sync** — Punch entries are automatically written to your daily markdown note. Configurable via `NOTE_DIR` environment variable.
- **Native macOS app** — Objective-C. Lightweight, no Electron overhead.
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
│  ┌────────────────────────────┐  │
│  │ 要做什么？                   │  │
│  └────────────────────────────┘  │
│  [✅ 打卡]                        │
│  [⏸ 暂停] [⏭ 跳过] [⟳ 重置]      │
│                                  │
│  📋 今天记录 ▾                    │
│  🎯 写邮件 · 08:25               │
│  🎯 看文档 · 08:15               │
└──────────────────────────────────┘
```

## Getting Started

### Native App (Objective-C)

```bash
# Compile
clang -fobjc-arc -framework Cocoa -o TimeBoxNative TimeBoxApp.m

# Run
./TimeBoxNative
```

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

TimeBox can log your punches to a daily markdown note. Set the `NOTE_DIR` environment variable to point to your notes folder:

```bash
export NOTE_DIR=~/Documents/Notes/Today/
```

The note file format is `YYYY-MM.md` with sections like `## M.D`:

```markdown
## Other stuff

## 6.3
09:30 写邮件给客户确认方案

## 6.2
16:00 代码审查
```

## Configuration

| Variable   | Default                     | Description                   |
|-----------|-----------------------------|-------------------------------|
| `NOTE_DIR` | `~/Documents/Notes/Today/` | Directory for daily note files |

Copy `.env.example` to `.env` to set your preferences.

## Project Structure

```
TimeBox/
├── TimeBoxApp.m          # Native macOS app (Objective-C)
├── serve.py              # HTTP server for HTML version
├── timebox.html          # HTML/JS timer (runs in browser or WKWebView)
├── TimeBoxWeb.swift      # Swift wrapper for HTML version
├── Sources/TimeBox/      # Swift package source
│   ├── TimeBox.swift     # Native Swift implementation
│   └── main.swift        # Entry point
├── Package.swift         # Swift Package Manager config
└── .env.example          # Environment configuration template
```

## License

MIT
