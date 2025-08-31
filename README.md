# radar.nvim

> Navigate your files like a fighter pilot.

A Neovim plugin that treats file navigation like a fighter pilot's radar system. Your most important files are "locked targets" that you can instantly access, while other files appear as "blips" on your radar for quick identification and engagement.

## ✨ Concept

`radar.nvim` provides **instant access** to your working files through spatial keyboard shortcuts, eliminating the need for fuzzy finders or file trees for your active working set.

- **📍 File Pinning**: Lock your most important files to slots 1-9 for instant access
- **🎯 Smart Persistence**: Context-aware storage per project and git branch
- **⚡ Dynamic Highlighting**: Auto-highlight the currently active pinned file
- **🛡️ Robust Error Handling**: Graceful handling of special characters and edge cases

See also [Concept](./docs/concept.md)

**Mini** Radar

![](./assets/mini.png)

**Full** Radar

![](./assets/full.png)

**Keybindings**

```
[1][2][3][4][5][6][7][8][9]  ← Loks (manually locked targets)
[q][w][e][r][t]              ← Modified files (git status)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[z][x][c][v][b]              ← PR files (branch changes)
```

This spatial keyboard layout gives you instant access to **24 files** without moving your left hand from home position.

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "black-atom-industries/radar.nvim",
  opts = {}
}
```

## 🎮 Usage

### Current Functionality

- **`,1` - `,9`**: Jump to pinned files
- **`,,`**: Pin or unpin the current file
- **`;q`**: Close the pins window

The plugin automatically shows a floating window with your pinned files and highlights the currently active one.

### Context-Aware Persistence

Pins are automatically saved and restored per project and git branch, so switching between projects or branches maintains separate pin sets.

## 🏗️ Architecture

This is a **learning project** demonstrating:

- Context-aware persistence with nested data structures
- Dynamic UI management with floating windows
- Extmarks for visual highlighting
- Safe string handling for special characters
- Robust error handling in dynamic environments

## 🎨 Interface Preview

```
┌─────────────────┐
│ 📌 Pins        │
│ [1] config.lua  │
│ [2] init.vim    │ ← highlighted (currently active)
│ [3] radar.lua   │
└─────────────────┘
```

## 📋 Roadmap

### v0.5 (Current)

- [x] File pinning with 1-9 keybindings
- [x] Context-aware persistence
- [x] Dynamic highlighting
- [x] Floating window UI
- [ ] Recent files section (vim.v.oldfiles integration)

### v1.0 (Planned)

- [ ] Modified files section (git integration)
- [ ] PR files section (branch changes)
- [ ] Mini radar (persistent) vs Full radar (on-demand) views
- [ ] Navigation mode between sections

## 🤝 Contributing

This is primarily a learning project focused on understanding Neovim plugin development patterns. Contributions are welcome, but please:

- Explain the "why" behind changes
- Maintain the spatial keybinding philosophy
- Keep code simple and educational
- Test with both basic and edge cases

## 📚 Learn More

- [docs/concept.md](docs/concept.md) - Comprehensive design vision and philosophy
- [CLAUDE.md](CLAUDE.md) - Technical architecture and development patterns

## 📄 License

MIT
