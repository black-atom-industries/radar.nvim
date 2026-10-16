# radar.nvim

> Navigate your files like a fighter pilot.

A Neovim plugin that treats file navigation like a fighter pilot's radar system. Your most important files are "locked targets" that you can instantly access, while other files appear as "blips" on your radar for quick identification and engagement.

## Concept

`radar.nvim` provides **instant access** to your working files through spatial keyboard shortcuts, eliminating the need for fuzzy finders or file trees for your active working set.

- **File Pinning**: Lock your most important files to slots 1-9 for instant access
- **Smart Persistence**: Context-aware storage per project and git branch
- **Sections**: One radar window with alternative file, locks, and recent files
- **Corner HUD**: A small always-visible window in the top-right corner with the alternative file, the first locks and recent files
- **Tab Navigation**: Sidebar view of all open tabs and buffers
- **Dynamic Highlighting**: Auto-highlight the currently active locked file

See also [Concept](./docs/concept.md)

**Keybindings**

```
<space> then:
[1][2][3][4][5][6][7][8][9]  ← Locks (manually locked targets)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[<Tab>]                      ← Alternative file (test ↔ impl)
[<space>]                    ← Full radar
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
      win_preset = "top_right",  -- see window presets below
      size = { width = 140, height = 25 },
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

| Option                                              | Default                               | Description                                                                     |
| --------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------- |
| `keys.prefix`                                       | `"<space>"`                           | Prefix that reads one more key; closes the radar inside it                      |
| `keys.lock`                                         | `"l"`                                 | Lock current buffer to a slot                                                   |
| `keys.locks`                                        | `{"1".."9"}`                          | Keys for lock slots                                                             |
| `keys.recent`                                       | `{"a".."g"}`                          | Keys for recent file slots                                                      |
| `keys.tabs_toggle`                                  | `"<leader>t"`                         | Toggle tabs sidebar                                                             |
| `keys.alternative`                                  | `"-"`                                 | Alternative file inside the radar                                               |
| `keys.hud_toggle`                                   | `"h"`                                 | Toggle the HUD for the session (after the prefix)                               |
| `keys.vertical` / `.horizontal` / `.tab` / `.float` | `<C-v>` / `<C-s>` / `<C-t>` / `<C-f>` | Split mode modifiers                                                            |
| `radar.size`                                   | `{ width = 50, height = 75 }`         | Window dimensions                                                               |
| `radar.win_preset`                                  | `"center"`                            | Window preset for the radar                                                     |
| `radar.border`                                      | `"solid"`                             | Border style (see `:h nvim_open_win`)                                           |
| `radar.max_recent_files`                            | `10`                                  | Max recent files shown                                                          |
| `radar.titles`                                      | (nerd font icons)                     | Section titles for main, locks, recent                      |
| `radar.win_opts`                                    | `{ cursorline = true, ... }`          | Window-local options applied to radar buffers                                   |
| `hud.enabled`                                       | `true`                                | Show the corner HUD                                                             |
| `hud.max_locks`                                     | `5`                                   | Locks shown in the HUD                                                          |
| `hud.max_recent`                                    | `3`                                   | Recent files shown in the HUD                                                   |
| `tabs.auto_close`                                   | `true`                                | Close tabs window after selecting                                               |
| `tabs.win_preset`                                   | `"center"`                            | Window preset for tabs sidebar                                                  |
| `radar_edit.win_preset`                             | `"center"`                            | Window preset for lock label editor                                             |
| `file_float.win_preset`                             | `"center_narrow"`                    | Window preset for floating file view                                            |
| `persist.path`                                      | `stdpath("data")/radar/data.json`     | Persistence file location                                                       |
| `persist.defer_ms`                                  | `500`                                 | Debounce delay for saves                                                        |
| `win_presets`                                       | `{}`                                  | Override or add custom window presets                                           |

**Available window presets** (for `win_preset` fields): `"cursor"`, `"center"`, `"center_large"`, `"center_narrow"`, `"top_left"`, `"top_right"`, `"bottom_left"`, `"bottom_right"`, `"bottom_center"`, `"full_height_sidebar"`

## Usage

### Default Keybindings

**Global:**

`<space>` waits for one more key:

- **`1-9`**: Jump to a lock
- **`a-g`**: Jump to a recent file
- **`<Tab>`**: Open the alternative file
- **`<space>`**: Open the radar
- **`l`**: Lock or unlock the current buffer
- **`h`**: Toggle the HUD for this session
- **`<Esc>`** or any other key: Cancel

- **`<leader>t`**: Toggle tabs sidebar

**Corner HUD:**

The HUD sits in the top-right corner of every tab, below the tabline. It shows the alternative file, up to 5 locks and 3 recent files with the keys that reach them after `<space>`, and highlights the current file. It moves to the bottom-right corner while the cursor is under it, and hides while the radar or the tabs sidebar is open and when there is nothing to show.

**Within Radar Window:**

- **`l`**: Lock or unlock the file under the cursor
- **`1-9`**: Open locked files
- **`a-g`**: Open recent files
- **`-`**: Open alternative file (e.g., test ↔ implementation)
- **`e`**: Edit lock labels
- **`t`**: Open tabs sidebar
- **`?`**: Toggle help
- **`<Tab>` / `<S-Tab>`**: Cycle focus between sections
- **`q` / `<Esc>` / `<space>`**: Close radar

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

**Split Modifiers (within radar, combine with 1-9, a-g, or `-`):**

- **`<C-v>` + key**: Open in vertical split
- **`<C-s>` + key**: Open in horizontal split
- **`<C-t>` + key**: Open in new tab
- **`<C-f>` + key**: Open in floating window

### Context-Aware Persistence

Locks are saved and restored per project and git branch, so switching between projects or branches maintains separate lock sets.

- The project is the git root containing the working directory (the worktree root inside a worktree), or the working directory outside git.
- Lock paths are stored relative to the project root.
- Detached HEAD and non-git directories keep locks in memory only, until you switch to another project.
- A corrupt data file is moved to `data.json.bad`. Writes are atomic.

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

### Development Dependencies

Some `make` targets require additional tools. Install them with:

| Tool | Purpose | Install |
|---|---|---|
| **StyLua** | Lua formatter | `brew install stylua` or `mise install stylua` |
| **lua-language-server** | Type checking | `brew install lua-language-server` or `mise install lua-language-server` |
| **Selene** | Lua linter | `cargo install selene` |
| **entr** | Test watch mode | `brew install entr` |

If you use [mise](https://mise.jdx.dev), run `mise install` to install `lua-language-server` and `stylua` automatically.

### Available Commands

| Command             | Description                     | Dependencies                              |
| ------------------- | ------------------------------- | ----------------------------------------- |
| `make test`         | Run all tests                   | None                                      |
| `make test-verbose` | Run tests with verbose output   | None                                      |
| `make test-watch`   | Watch for changes and run tests | `entr` (`brew install entr`)              |
| `make validate`     | Validate test setup             | None                                      |
| `make check`        | Run all linters and type checks | `stylua`, `lua-language-server`, `selene` |
| `make lint`         | Check Lua formatting            | `stylua` (`brew install stylua`)          |
| `make typecheck`    | Run type checking               | `lua-language-server`                     |
| `make selene`       | Run selene linter               | `selene` (`cargo install selene`)         |
| `make format`       | Format Lua files                | `stylua` (`brew install stylua`)          |
| `make install-hooks`| Enable pre-commit hooks         | None                                      |
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
│   [-] test/spec/locks_spec.lua                                    │
└───────────────────────────────────────────────────────────────────┘

┌── 󰋱  LOCKED IN ──────────────┐   ┌── 󰽏  NEAR ──────────────────┐
│   [1] lua/radar/init.lua      │   │   [a] README.md              │
│   [2] lua/radar/config.lua  ← │   │   [s] AGENTS.md              │
│   [3] test/spec/state.lua     │   │   [d] lua/radar/ui/keys.lua │
│                               │   │   [e] lua/radar/ui/window.lua │
│                               │   │   [f] lua/radar/data/locks.lua │
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
