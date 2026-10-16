# radar.nvim - Concept & Design

> Navigate your files at the speed of thought - like a fighter pilot's radar display

## 🎯 Core Philosophy

`radar.nvim` treats file navigation like a fighter pilot's radar system. Your most important files are "locked targets" that you can instantly access, while other files appear as "blips" on your radar that you can quickly identify and engage.

The plugin has two parts that work together:

- **HUD**: A small, always-visible window at the bottom of the active pane showing the current and alternative file, your first locks and recent files
- **Prefix Keys**: `<space>` plus one key jumps to any file the HUD labels, and to locks and recent files past what it shows

## 🚀 Key Features

### Instant Access

- Single-key navigation to your most important files
- No need for fuzzy finders or file trees for your active working set
- Visual persistence - always see your pinned files at a glance

### Smart Categorization

Files are automatically organized into tactical categories:

- **📍 Pins**: Manually locked priority targets (your most important files)
- **🔄 Modified**: Files with uncommitted changes
- **📜 Recent**: Recently opened files, kept per project and branch, with oldfiles as a fallback
- **🔀 PR Files**: Files changed in the current PR/branch

### Direct Access

`<space>` and a single key open any file with a binding. The HUD shows which key reaches which file.

## ⌨️ Keybinding Design

The keybindings follow a spatial layout on your keyboard - your fingers move down the keyboard as you move down through categories:

```
[1][2][3][4][5][6][7][8][9]  ← Pins (most important)
[q][w][e][r][t]              ← Modified files
[a][s][d][f][g]              ← Recent files
[z][x][c][v][b]              ← PR files
```

This gives you instant access to 24 files without moving your left hand from home position.

## 🎨 Interface Design

### HUD (Persistent)

```
 [o] spec.lua
 [1] config.lua
 [2] init.lua
 [a] radar.lua
 [s] setup.ts
```

- One per tab, anchored to the bottom of the active pane and as wide as it
- Shows the current file, the alternative file, up to 5 locks and 3 recent files; a locked current file is highlighted
- Labels are the keys that follow `<space>`: `<space>1` jumps to lock 1, `<space>a` to the first recent file, `<space>o` to the alternative file
- Moves to the top of the pane while the cursor line runs under it
- Updates as you lock; hidden while the tabs sidebar or the lock editor is open and when empty; `<space>h` toggles it for the session

## 🔧 Configuration

```lua
require("radar").setup({
  keys = {
    prefix = "<space>",                             -- reads one more key
    alternative = "o",                              -- <space>o opens the alternative file
    hud_toggle = "h",                               -- <space>h toggles the HUD
    edit = "e",                                     -- <space>e opens the lock editor at the bottom of the pane
    help = "?",                                     -- <space>? lists the keys after the prefix
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    recent = { "a", "s", "d", "f", "g" },
  },

  recent = {
    max_files = 10,                                 -- recent files kept per project and branch
  },

  hud = {
    enabled = true,
    max_locks = 5,
    max_recent = 3,
  },

  persist = {
    path = vim.fn.stdpath("data") .. "/radar/data.json",
  },
})
```

## 📝 File Overlap Strategy

When files appear in multiple categories (e.g., a pinned file that's also modified), the plugin handles this intelligently:

### Version 1.0 (Deduplication)

- Pinned files are filtered out of other sections
- Each file appears in only one section
- Simple mental model: Pins are "priority locks" that override other categories

### Future Versions (Planned)

- Visual indicators for files in multiple categories
- Dynamic promotion system (promote files between sections)
- Scrollable sections with "hot zones" for keybindings
- Smart filtering based on context

## 🎯 Use Cases

### The Working Set

Pin the 3-5 files you're actively working on. These are your primary targets - always visible, always accessible with a single keypress.

### The Context Switch

Glance at the HUD when switching contexts. It shows the alternative file, your locks and what you were working on recently on this branch.

### The Quick Jump

Stop hunting through file trees or typing fuzzy search patterns for files you access frequently. Just hit `<space>3` to jump to that config file you pinned.

## 🚦 Roadmap

### Version 0.5 (MVP)

- [x] HUD with pinned and recent files
- [x] Basic keybindings (1-9 for pins)
- [ ] Deduplication logic
- [ ] Basic configuration
- [ ] Readme
- [ ] ROADMAP.md
- [ ] Changelog and Releases

### Version 1.0

- [ ] Modified files section (git integration)
- [ ] PR files section (git integration)
- [ ] Persistent pins across sessions

## 💡 Design Principles

1. **Speed First**: Every interaction should be instantaneous
2. **Visual Persistence**: Important information stays visible
3. **Spatial Logic**: Keybindings follow physical keyboard layout
4. **Progressive Disclosure**: Simple by default, powerful when needed
5. **No Magic**: Clear, predictable behavior that users can reason about

## 🤝 Contributing

This plugin is being built as a learning project. Contributions are welcome, but the focus is on understanding and implementing core concepts rather than just adding features.

If you're contributing, please:

- Explain the "why" behind your changes
- Keep the code simple and readable
- Maintain the spatial keybinding philosophy
- Test with the HUD and the prefix keys

## 📚 Inspiration

- Fighter pilot HUD/radar displays
- Vim's marks system (but visual and persistent)
- The need for speed in file navigation
- Frustration with losing context when using fuzzy finders
