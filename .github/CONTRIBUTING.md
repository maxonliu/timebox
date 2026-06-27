# Contributing to TimeBox

Thanks for your interest in TimeBox! 🎉

TimeBox is a small, focused macOS app. The codebase is intentionally minimal — a single Objective-C file. Before contributing, please read the project philosophy below.

## Project Philosophy

- **Keep it simple.** One `.m` file, zero dependencies, no build system. If a feature requires a package manager or significant complexity, it probably doesn't belong here.
- **Stay native.** Pure Cocoa/Objective-C. No Electron, no web wrappers.
- **Stay focused.** TimeBox does one thing: 10-minute time-boxing. It doesn't need to become a full productivity suite.

## How to Contribute

### 🐛 Report Bugs

Open an issue describing:
- What you expected
- What actually happened
- macOS version and hardware (Intel / Apple Silicon)

### 💡 Suggest Features

Open an issue with the `enhancement` label. Describe the problem you're solving, not just the solution. Small, focused additions are welcomed.

### 🛠 Submit Code

1. Fork the repo
2. Create a branch (`git checkout -b feat/your-change`)
3. Make your changes in `TimeBoxApp.m`
4. Build and test:

   ```bash
   clang -fobjc-arc -framework Cocoa -o TimeBoxNative TimeBoxApp.m
   ./TimeBoxNative
   ```

5. Commit with a clear message
6. Push and open a Pull Request

### ✅ PR Guidelines

- One feature/fix per PR
- Keep changes minimal — no reformatting or renaming unless it's the point of the PR
- If your change affects the UI, include a screenshot
- The Build workflow must pass (it compiles the project on macOS)

## Code of Conduct

Please read [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Be respectful, constructive, and patient.
