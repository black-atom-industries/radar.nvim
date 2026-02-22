# radar.nvim

> Navigate your files like a fighter pilot.

A Neovim plugin that treats file navigation like a fighter pilot's radar system. Your most important files are "locked targets" that you can instantly access, while other files appear as "blips" on your radar for quick identification and engagement.

## Concept

`radar.nvim` provides **instant access** to your working files through spatial keyboard shortcuts, eliminating the need for fuzzy finders or file trees for your active working set.

- **File Pinning**: Lock your most important files to slots 1-9 for instant access
- **Smart Persistence**: Context-aware storage per project and git branch
- **Grid Layout**: Multi-section radar display with locks, recent files, and alternative file
- **Tab Navigation**: Sidebar view of all open tabs and buffers
- **Dynamic Highlighting**: Auto-highlight the currently active pinned file

See also [Concept](./docs/concept.md)

**Keybindings**

```
[1][2][3][4][5][6][7][8][9]  ← Locks (manually locked targets)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[<space>]                    ← Alternative file (test ↔ impl)
```

This spatial keyboard layout gives you instant access to **15 files** without moving your left hand from home position.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "black-atom-industries/radar.nvim",
  opts = {}
}
```

### Configuration Examples

**Simple customization:**

```lua
{
  "black-atom-industries/radar.nvim",
  opts = {
    radar = {
      position = "top_right",  -- "center", "top_left", "top_right", "bottom_left", "bottom_right"
      grid_size = { width = 140, height = 25 },
      max_recent_files = 10,
      titles = {
        main = "MY RADAR",
        locks = "LOCKED",
      }
    }
  }
}
```

**Customize tabs sidebar:**

```lua
{
  "black-atom-industries/radar.nvim",
  opts = {
    keys = {
      tabs_toggle = "<leader>b",  -- default: "<leader>t"
    },
    tabs = {
      auto_close = false,  -- keep open after selecting
      win_preset = "center",
    }
  }
}
```

## Configuration Reference

For full type definitions see [`config.types.lua`](lua/radar/config.types.lua). For all defaults see [`config.lua`](lua/radar/config.lua).

| Option | Default | Description |
|--------|---------|-------------|
| `keys.prefix` | `"<space>"` | Toggle radar / alternative file (double-tap) |
| `keys.lock` | `"l"` | Lock current buffer to a slot |
| `keys.locks` | `{"1".."9"}` | Keys for lock slots |
| `keys.recent` | `{"a".."g"}` | Keys for recent file slots |
| `keys.tabs_toggle` | `"<leader>t"` | Toggle tabs sidebar |
| `keys.alternative` | `nil` (= prefix) | Key for alternative file; nil defaults to prefix |
| `keys.vertical` / `.horizontal` / `.tab` / `.float` | `<C-v>` / `<C-s>` / `<C-t>` / `<C-f>` | Split mode modifiers |
| `radar.position` | `"center"` | Grid position: `center`, `top_left`, `top_right`, `bottom_left`, `bottom_right` |
| `radar.grid_size` | `{ width = 125, height = 20 }` | Total grid dimensions |
| `radar.border` | `"single"` | Border style (see `:h nvim_open_win`) |
| `radar.max_recent_files` | `25` | Max recent files shown |
| `radar.titles` | (nerd font icons) | Section titles for main, locks, alternative, recent, hints |
| `radar.win_opts` | `{ cursorline = true, ... }` | Window-local options applied to radar buffers |
| `tabs.auto_close` | `true` | Close tabs window after selecting |
| `tabs.win_preset` | `"center"` | Window preset for tabs sidebar |
| `radar_edit.win_preset` | `"center"` | Window preset for lock label editor |
| `file_float.win_preset` | `"center_large"` | Window preset for floating file view |
| `persist.path` | `stdpath("data")/radar/data.json` | Persistence file location |
| `persist.defer_ms` | `500` | Debounce delay for saves |
| `win_presets` | `{}` | Override or add custom window presets |

**Available window presets** (for `win_preset` fields): `"center"`, `"center_large"`, `"cursor"`, `"top_right"`, `"bottom_center"`, `"full_height_sidebar"`

## Usage

### Default Keybindings

**Global:**

- **`<space>`**: Toggle radar window
- **`<leader>t`**: Toggle tabs sidebar

**Within Radar Window:**

- **`l`**: Lock current buffer (from source window)
- **`1-9`**: Open locked files
- **`a-g`**: Open recent files
- **`<space>`**: Open alternative file (e.g., test ↔ implementation)
- **`e`**: Edit lock labels
- **`<Tab>` / `<S-Tab>`**: Cycle focus between sections
- **`q` / `<Esc>`**: Close radar

**Within Tabs Sidebar:**

- **`<CR>`**: Jump to tab/buffer
- **`x`**: Close buffer or tab
- **`q` / `<Esc>`**: Close tabs sidebar

**Line-based Navigation (within radar):**

- **`<CR>`**: Open file under cursor
- **`V`**: Open in vertical split
- **`S`**: Open in horizontal split
- **`T`**: Open in new tab
- **`F`**: Open in floating window

**Split Modifiers (combine with 1-9, a-g, or `<space>`):**

- **`<C-v>` + key**: Open in vertical split
- **`<C-s>` + key**: Open in horizontal split
- **`<C-t>` + key**: Open in new tab
- **`<C-f>` + key**: Open in floating window

### Context-Aware Persistence

Locks are automatically saved and restored per project and git branch, so switching between projects or branches maintains separate lock sets.

### Data Cleanup

Over time, your persistence data file can accumulate entries for deleted branches or old projects. Use the cleanup command to remove stale entries:

```vim
:RadarCleanup          " Remove entries for branches that no longer exist
:RadarCleanup --dry-run  " Preview what would be deleted without making changes
```

**What gets cleaned:**

- Entries for projects whose directories no longer exist
- Entries for git branches that have been deleted
- Current branch is always preserved (fail-safe)

**From Lua:**

```lua
require("radar").cleanup()                    -- Remove stale entries
require("radar").cleanup({ dry_run = true })  -- Preview only
```

## Testing

This plugin includes tests using [mini.test](https://github.com/echasnovski/mini.test) with busted-style syntax.

### Available Commands

| Command             | Description                     | Dependencies                              |
| ------------------- | ------------------------------- | ----------------------------------------- |
| `make test`         | Run all tests                   | None                                      |
| `make test-path`    | Run only path utility tests     | None                                      |
| `make test-verbose` | Run tests with verbose output   | None                                      |
| `make test-watch`   | Watch for changes and run tests | `entr` (`brew install entr`)              |
| `make validate`     | Validate test setup             | None                                      |
| `make check`        | Run all linters and type checks | `stylua`, `lua-language-server`, `selene` |
| `make lint`         | Lint Lua files                  | `stylua` (`brew install stylua`)          |
| `make typecheck`    | Run type checking               | `lua-language-server`                     |
| `make selene`       | Run selene linter               | `selene` (`cargo install selene`)         |
| `make format`       | Format Lua files                | `stylua` (`brew install stylua`)          |
| `make clean`        | Clean test artifacts            | None                                      |
| `make help`         | Show all available commands     | None                                      |

### Writing Tests

Tests are located in `test/spec/` and use mini.test with busted emulation:

```lua
describe("my feature", function()
  it("should work correctly", function()
    MiniTest.expect.equality(result, expected)
  end)
end)
```

## Interface Preview

```
┌──────── 󰐷  RADAR ────────────────────────────────────────────────┐
│   OTHER                                                          │
│   [<space>] test/spec/locks_spec.lua                              │
└───────────────────────────────────────────────────────────────────┘

┌── 󰋱  LOCKED IN ──────────────┐   ┌── 󰽏  NEAR ──────────────────┐
│   [1] lua/radar/init.lua      │   │   [a] README.md              │
│   [2] lua/radar/config.lua  ← │   │   [s] AGENTS.md              │
│   [3] test/spec/state.lua     │   │   [d] lua/radar/keys.lua     │
│                               │   │   [e] lua/radar/window.lua   │
│                               │   │   [f] lua/radar/locks.lua    │
└───────────────────────────────┘   └──────────────────────────────┘
```

## Contributing

This is primarily a learning project focused on understanding Neovim plugin development patterns. Contributions are welcome, but please:

- Explain the "why" behind changes
- Maintain the spatial keybinding philosophy
- Keep code simple and educational
- Test with both basic and edge cases

## Learn More

- [docs/concept.md](docs/concept.md) - Comprehensive design vision and philosophy
- [AGENTS.md](AGENTS.md) - Technical architecture and development patterns

## License

MIT
