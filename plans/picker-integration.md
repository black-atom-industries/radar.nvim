# Picker Integration for Full Radar

## Overview

Integration of a minimal picker component into radar.nvim's full radar mode, enabling fuzzy search across all file categories while maintaining the spatial keyboard layout philosophy.

## Source Code Reference

**Original picker implementation**: https://raw.githubusercontent.com/santhosh-tekuri/dotfiles/refs/heads/master/.config/nvim/lua/picker.lua

Key characteristics of the source picker:
- ~200 lines of clean, focused code
- Uses `matchfuzzypos()` for built-in fuzzy matching
- Floating window with dynamic content updates
- Flexible item sources and callback system
- Timer-based debouncing for live updates
- Multiple open strategies (edit, split, vsplit, tab)

## Integration Vision

### Trigger Mechanism
- Press `/` while in full radar mode to enter search mode
- Search interface overlays or transforms the current radar display
- Maintains context of current file categories and spatial layout

### Search Behavior
```
Full Radar Display:
[1][2][3][4][5][6][7][8][9]  ← Pins (manually locked targets)
[q][w][e][r][t]              ← Modified files (git status)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[z][x][c][v][b]              ← PR files (branch changes)

Search Mode (/) Input: "comp"
Results:
[1] components/Header.tsx     ← Pin match
[q] src/components/App.tsx    ← Modified match  
[a] lib/compiler.ts           ← Recent match
```

### Core Architecture Alignment

Both picker and radar share similar patterns:
- **Floating window management** - Same as mini radar
- **Dynamic buffer updates** - Like `update_mini_radar()`
- **Namespace-based highlighting** - Using extmarks
- **State management** - Similar to radar's state object

## Implementation Considerations

### Search Scope Options
1. **Unified search** - Single search across all categories
2. **Category-aware search** - Search within specific sections
3. **Hybrid approach** - Search all but maintain category ordering

### Visual Integration
1. **Overlay mode** - Picker appears over radar display
2. **Transform mode** - Radar morphs into picker interface
3. **Split mode** - Search results appear alongside spatial layout

### Result Prioritization
- Maintain deduplication logic (pins override other categories)
- Category-based ordering vs. search relevance ranking
- Preserve spatial keyboard mappings where possible

## Technical Integration Points

### File Collection System
```lua
-- Extend current radar to collect all file categories
M.collect_all_files = function()
    return {
        pins = M.state.locks,
        modified = get_git_modified_files(),
        recent = filter_recent_files(),
        pr_files = get_pr_changed_files()
    }
end
```

### Picker Configuration
```lua
-- Adapt picker for radar context
local radar_picker_config = {
    items = M.collect_all_files(),
    prompt = "RADAR SEARCH: ",
    format_item = format_radar_item,
    on_select = open_radar_file,
    preview = true -- Show file preview
}
```

### Key Mapping Strategy
- Preserve spatial keybindings during search when possible
- Fallback to picker's navigation (j/k, C-n/C-p) for filtered results
- ESC returns to normal radar mode

## Future Enhancements

### Search Modes
- **File content search** - Beyond filename matching
- **Symbol search** - LSP integration for code navigation
- **Project-wide grep** - Full-text search with context

### Smart Filtering
- **Frecency algorithm** - Combine frequency + recency
- **Context awareness** - Prioritize files related to current work
- **Git integration** - Weight files by change activity

## Implementation Timeline

**Phase 1**: Basic picker integration
- Implement `/` trigger in full radar mode
- Adapt picker code for radar file collections
- Maintain spatial keyboard layout compatibility

**Phase 2**: Enhanced search features
- Add file content search capabilities
- Implement preview functionality
- Add search history and persistence

**Phase 3**: Advanced navigation
- Symbol-level search integration
- Project-wide search capabilities
- Smart ranking and frecency algorithms

## Code Integration Notes

The picker's modular design makes it suitable for integration:
- Single file implementation (~200 lines)
- No external dependencies beyond Neovim API
- Flexible callback system for radar integration
- Similar architectural patterns to existing radar code

## Questions for Future Implementation

1. Should search maintain category separation or unified results?
2. How to handle search result persistence across radar sessions?
3. Integration with existing keybinding system and spatial layout?
4. Preview functionality - show file content during search?
5. Search history - remember and suggest previous searches?

## References

- Original picker: santhosh-tekuri/dotfiles
- Current radar implementation: `lua/radar/init.lua`
- Radar concept document: `docs/concept.md`
- Spatial keyboard layout: 24-key instant access system
