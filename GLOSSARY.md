# Ubiquitous Language

## Places you jump to

| Term                 | Definition                                                                                  | Aliases to avoid                        |
| -------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------- |
| **Current file**     | The file in the active pane, shown first in the Lock HUD as `%`                             | Source buffer (outside code), this file |
| **Alternative file** | The pane's previous file (Vim's `#`), reached with `o`                                      | Other file, alt file, double-tap file   |
| **Lock**             | A file or directory the user pinned to a numbered slot for the current project and branch   | Pin, locked target, mark                |
| **Recent file**      | A file opened in the project lately, outside the locks and the alternative file             | Near file, blip, oldfile                |
| **Recent history**   | The saved list of recent files per project and branch, with `vim.v.oldfiles` as fallback    | MRU, oldfiles                           |
| **Label**            | The key that reaches an entry after the prefix: `1`-`9` for locks, `a`-`g` for recent files | Slot number, index                      |

## Interface

| Term                   | Definition                                                                                     | Aliases to avoid                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **Lock HUD** (updated) | The always-visible float at the bottom of the active pane listing the places you can jump to   | HUD (alone), mini window, menu window, corner HUD, mini radar |
| **Prefix**             | The `<space>` key that waits for one more key and acts on it                                   | Leader, radar key                                             |
| **Lock editor**        | The editable float in the Lock HUD's place where each line is a lock path                      | Edit window, radar edit                                       |
| **Tab HUD** (updated)  | The float in the Lock HUD's place listing every tab and the buffers shown in it                | Tabs view, tabs sidebar, drawer                               |
| **Pane**               | A normal (non-floating) window that the Lock HUD, lock editor and Tab HUD attach to            | Split, window (when a float could be meant)                   |
| **Dodge**              | The Lock HUD moving to the top of its pane while the cursor line runs under it                 | Flip, jump away                                               |
| **Radar window**       | The removed centered window that listed locks and recent files; not part of the plugin anymore | Big window, radar, main radar                                 |

## Persistence

| Term           | Definition                                                                                    | Aliases to avoid                  |
| -------------- | --------------------------------------------------------------------------------------------- | --------------------------------- |
| **Project**    | The git root containing the working directory (the worktree root in a worktree), else the cwd | Workspace, cwd, repo              |
| **Branch**     | The git branch checked out in the project; locks and recent history are kept per branch       | Context                           |
| **Data file**  | The JSON file that stores locks and recent history for every project and branch               | Persistence file, state file      |
| **Quarantine** | Moving an unreadable data file to `data.json.bad` instead of overwriting it                   | Backup, reset                     |
| **Prune**      | Removing locks whose file or directory no longer exists                                       | Cleanup (that is `:RadarCleanup`) |
| **Relabel**    | Renumbering locks by position so their labels have no gaps                                    | Reorder, compact                  |
| **Cleanup**    | `:RadarCleanup`: removing data for branches and projects that no longer exist                 | Prune                             |

## Relationships

- A **Project** has many **Branches**; each **Branch** has its own **Locks** and **Recent history** in the **Data file**.
- A **Lock** has exactly one **Label**; **Relabel** keeps labels `1..n` in list order.
- The **Lock HUD** shows one **Current file**, at most one **Alternative file**, up to five **Locks** and up to three **Recent files**.
- The **Lock HUD**, the **Lock editor** and the **Tab HUD** share one spot: the bottom of the active **Pane**; only one of them shows at a time.
- **Prune** acts on **Locks** of the current **Branch**; **Cleanup** acts on whole **Branches** and **Projects** in the **Data file**.

## Example dialogue

> **Dev:** "When I open a file with `<space>a`, does it become a **Lock**?"
> **Domain expert:** "No. `a` is a **Recent file**'s **Label**. Only `<space>l` turns the **Current file** into a **Lock**."
> **Dev:** "And the **Alternative file**, can it also be a **Recent file**?"
> **Domain expert:** "It's shown once, on the `o` line. **Recent files** leave out the **Current file**, the **Alternative file** and every **Lock**."
> **Dev:** "If I delete a locked file, does `:RadarCleanup` remove it?"
> **Domain expert:** "That's **Prune**, and it happens on its own when the **Branch** loads. **Cleanup** is for **Branches** or **Projects** that are gone from disk."
> **Dev:** "And `<space>t` replaces the **Lock HUD**?"
> **Domain expert:** "The **Tab HUD** takes the **Lock HUD**'s spot in the **Pane** while it's open, at least as tall as the **Lock HUD**, then the **Lock HUD** comes back."

## Flagged ambiguities

- "radar" meant three things: the plugin, the removed **Radar window**, and the `<space>` **Prefix**. Use "radar.nvim" for the plugin and **Radar window** only for the removed window; the key is the **Prefix**.
- "HUD", "mini window", "menu window" and "corner HUD" were used for both floats. Say **Lock HUD** for the list of places to jump to and **Tab HUD** for the list of tabs and buffers; they share a spot, nothing else. (updated)
- "other file" (in key descriptions) and "alternative file" name the same thing. Use **Alternative file**; `o` is just its key.
- "cleanup" was used for removing missing locks and for `:RadarCleanup`. Removing locks of missing files is **Prune**; removing stale branches and projects is **Cleanup**.
- "label" sometimes meant a lock's custom name in the old edit flow. A **Label** is only the key; locks have no custom names.
- "tabs sidebar" and "tabs view" name the **Tab HUD**. Code identifiers (`ui/hud.lua`, `ui/tabs.lua`, `keys.tabs_toggle`) keep their names; prose says **Lock HUD** and **Tab HUD**. (updated)
