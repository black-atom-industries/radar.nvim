# radar.nvim - Concept & Design

> Navigate your files at the speed of thought - like a fighter pilot's radar display

## 🎯 Core Philosophy

`radar.nvim` treats file navigation like a fighter pilot's radar system. Your most important files are "locked targets" that you can instantly access, while other files appear as "blips" on your radar that you can quickly identify and engage.

The plugin provides two complementary views:

- **Mini Radar**: A persistent, always-visible floating window showing your pinned files
- **Full Radar**: A comprehensive tactical display showing all file categories

## 🚀 Key Features

### Instant Access

- Single-key navigation to your most important files
- No need for fuzzy finders or file trees for your active working set
- Visual persistence - always see your pinned files at a glance

### Smart Categorization

Files are automatically organized into tactical categories:

- **📍 Pins**: Manually locked priority targets (your most important files)
- **🔄 Modified**: Files with uncommitted changes
- **📜 Recent**: Recently accessed files from oldfiles
- **🔀 PR Files**: Files changed in the current PR/branch

### Dual Navigation Modes

1. **Direct Access**: Single keypress to open any file with a binding
2. **Navigation Mode**: Navigate `radar` panes to browse and `<CR>` to open

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

### Mini Radar (Persistent)

```
┌─────────────────┐
│ 🎯  Locks       │
│ [1] config.lua  │
│ [2] init.vim    │
│ [3] radar.lua   │
│ [4] setup.ts    │
└─────────────────┘
```

- Always visible in corner of your screen
- Shows only locked files for minimal distraction
- Instant visual reference for your working set

### Full Radar (`<leader>r`)

```
┌─────────────────────┬───────────────────┐
│ 📍 Pins [1-9]       │ 🔄 Modified [q-t] │
│ 1. config.lua       │ q. changed.ts     │
│ 2. init.vim         │ w. updated.tsx    │
├─────────────────────┼───────────────────┤
│ 📜 Recent [a-g]     │ 🔀 PR Files [z-b] │
│ a. recent1.ts       │ z. pr-file1.tsx   │
│ s. recent2.tsx      │ x. pr-file2.ts    │
└─────────────────────┴───────────────────┘
```

- Comprehensive tactical overview
- Grid layout for maximum information density
- Both navigation and direct keybindings

## 🔧 Configuration

```lua
require('radar').setup({
  keys = {
    prefix = '<leader>',      -- Prefix for all keybindings
    pins = '123456789',      -- number row
    modified = 'qwert',       -- upper row
    recent = 'asdfg',         -- home row
    pr_files = 'zxcvb',       -- bottom row
  },

  behaviour = {
    deduplicate = true,         -- Remove pinned files from other sections
    persist_pins = true,        -- Save pins between sessions
  },

  appearance = {
    mini = {
      --- If static, the mini radar will always be visible (My personal preference)
      --- If dynamic, the mini radar will only be visible when pressing the prefix key, until picking a file
      ---@alias radar.config.appearance.mini.display "static" | "dynamic"
      display = "static",
      ---@alias radar.config.appearance.mini.preset "sidebar_left" | "sidebar_right" | "float_top_right" | "float_top_left" | "float_bottom_right" | "float_bottom_left"
      preset = "float_top_right",
      ---@type vim.api.keyset.win_config
      config = {}
    },
    full = {
        ---@type vim.api.keyset.win_config
        config = {}
    },
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

Use the full radar when switching contexts. Quickly see what you've modified, what's in your PR, and what you were working on recently.

### The Quick Jump

Stop hunting through file trees or typing fuzzy search patterns for files you access frequently. Just hit `3` to jump to that config file you pinned.

## 🚦 Roadmap

### Version 0.5 (MVP)

- [x] Mini radar with pinned and recent files
- [x] Basic keybindings (1-9 for pins)
- [ ] Deduplication logic
- [ ] Basic configuration
- [ ] Readme
- [ ] ROADMAP.md
- [ ] Changelog and Releases

### Version 1.0

- [ ] Modified files section (git integration)
- [ ] PR files section (git integration)
- [ ] Navigation mode (between full radar sections)
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
- Test with both mini and full radar views

## 📚 Inspiration

- Fighter pilot HUD/radar displays
- Vim's marks system (but visual and persistent)
- The need for speed in file navigation
- Frustration with losing context when using fuzzy finders

