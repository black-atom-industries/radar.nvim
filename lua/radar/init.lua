local M = {}

M.constants = {
    ns_mini_win = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config
M.config = {
    keys = {
        prefix = ",",
        lock = ",,",
        locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }, -- num row
        modified = { "q", "w", "e", "r", "t" }, -- upper row
        recent = { "a", "s", "d", "f", "g" }, -- home row
        pr_files = { "z", "x", "c", "v", "b" }, -- bottom row
    },

    -- See :h filename-modifiers
    path_format = ":p:.",

    ---@type vim.api.keyset.win_config
    win = {
        width = 50,
        relative = "editor",
        anchor = "NW",
        title = "📌 Pins",
        title_pos = "left",
        style = "minimal",
        border = "solid",
        focusable = false,
        zindex = 100,
    },

    persist = {
        -- Path to persist session data in
        path = vim.fs.joinpath(vim.fn.stdpath("data"), "pins"),
        filename = "data.json",
    },
}

---@class Pin
---@field label string
---@field filename string

---@class Pins.State
M.state = {
    ---@type Pin[]
    pins = {},
    pin_board_win = nil,
    ---@param field "label" | "filename"
    ---@param value string
    get_pin_by_field = function(field, value)
        for _, p in ipairs(M.state.pins) do
            if p[field] == value then
                return p
            end
        end
    end,
    ---@param filename string
    get_pin_from_filename = function(filename)
        return M.state.get_pin_by_field("filename", filename)
    end,
    get_pin_from_label = function(label)
        return M.state.get_pin_by_field("label", label)
    end,
}

function M:get_next_unused_pin_label()
    local used_labels = {}
    for _, p in ipairs(self.state.pins) do
        table.insert(used_labels, p.label)
    end

    for _, label in ipairs(self.config.keys.locks) do
        if not vim.tbl_contains(used_labels, label) then
            return label
        end
    end

    error("No more pins available")
end

function M:write(path, tbl)
    local ok, _ = pcall(function()
        local fd = assert(vim.uv.fs_open(path, "w", 438)) -- 438 = 0666
        assert(vim.uv.fs_write(fd, vim.json.encode(tbl)))
        assert(vim.uv.fs_close(fd))
    end)

    return ok
end

function M:read(path)
    local ok, content = pcall(function()
        local fd = assert(vim.uv.fs_open(path, "r", 438)) -- 438 = 0666
        local stat = assert(vim.uv.fs_fstat(fd))
        local data = assert(vim.uv.fs_read(fd, stat.size, 0))
        assert(vim.uv.fs_close(fd))
        return data
    end)

    return ok and vim.json.decode(content) or nil
end

---@param filename string
---@returns Pin
function M:add_pin(filename)
    local next_free_pin_label = M:get_next_unused_pin_label()

    ---@type Pin
    local pin = {
        label = next_free_pin_label,
        filename = filename,
    }

    table.insert(self.state.pins, pin)
    return pin
end

---@param filename string
---@return Pin
function M:remove_pin(filename)
    ---@type Pin
    local removed_pin

    for i, p in ipairs(self.state.pins) do
        if p.filename == filename then
            removed_pin = p
            table.remove(self.state.pins, i)
            break
        end
    end

    return removed_pin
end

function M:get_project_path()
    local cwd = vim.uv.cwd()

    if not cwd then
        return nil
    end

    local sanitized_path = vim.fn.fnameescape(cwd)
    return vim.fn.fnamemodify(sanitized_path, ":~")
end

-- TODO: Could not be a git project
function M:get_git_branch()
    local branch = vim.fn.systemlist("git branch --show-current")[1]
    if branch == "" then
        return nil
    end

    local sanitized_branch = vim.fn.fnameescape(branch)
    return sanitized_branch
end

function M:get_persist_file_path()
    return self.config.persist.path .. "/" .. self.config.persist.filename
end

function M:load()
    local is_readable = vim.fn.filereadable(self.config.persist.path)
    if is_readable == 1 then
        return self:read(self.config.persist.path)
    else
        return nil
    end
end

function M:persist()
    local project_path = M:get_project_path()
    local git_branch = M:get_git_branch()

    local persisted_data = M:load()
    local data

    if persisted_data == nil then
        data = {
            [project_path] = {
                [git_branch] = {
                    pins = self.state.pins,
                },
            },
        }
    else
        data = vim.tbl_deep_extend("force", persisted_data, {
            [project_path] = {
                [git_branch] = {
                    pins = self.state.pins,
                },
            },
        })
    end

    vim.fn.mkdir(self.config.persist.path, "p")
    self:write(self:get_persist_file_path(), data)
    return data
end

function M:populate()
    local data = self:read(self:get_persist_file_path())

    if data ~= nil then
        local project_path = M:get_project_path()
        local git_branch = M:get_git_branch()
        local persisted_pins = vim.tbl_get(data, project_path, git_branch, "pins")

        if persisted_pins == nil then
            return
        end

        self.state.pins = persisted_pins

        if #persisted_pins > 0 then
            M:create_board()
        end
    end
end

---@param filename string
---@return Pin
function M:toggle_pin(filename)
    local exists = self.state.get_pin_from_filename(filename)

    local pin

    if not exists then
        pin = M:add_pin(filename)
    else
        pin = M:remove_pin(filename)
    end

    vim.defer_fn(function()
        self:persist()
    end, 500)

    return pin
end

function M:does_pin_board_exist()
    return self.state.pin_board_win and vim.api.nvim_win_is_valid(self.state.pin_board_win)
end

---If no buf_nr is provided it uses its current buf
---@param buf_nr? integer
---@return string
function M:get_current_filename(buf_nr)
    buf_nr = buf_nr or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_get_name(buf_nr)
end

---@param buf_nr integer
function M:pin(buf_nr)
    local filename = M:get_current_filename(buf_nr)
    M:toggle_pin(filename)

    if #M.state.pins == 0 and M:does_pin_board_exist() then
        vim.api.nvim_win_close(M.state.pin_board_win, true)
    end

    if not M:does_pin_board_exist() then
        M:create_board()
    else
        M:update_board()
    end
end

function M:is_current_file_pinned()
    local current_file = self:get_current_filename()

    local is_pinned = false

    for _, pin in ipairs(self.state.pins) do
        if pin.filename == current_file then
            is_pinned = true
            break
        end
    end

    return is_pinned
end

vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("pins_read", { clear = true }),
    callback = function()
        M:highlight_active_pin()
    end,
})

---@param label string
function M:open_pin(label)
    local pin = self.state.get_pin_from_label(tostring(label))
    local path = vim.fn.fnameescape(pin.filename)
    vim.cmd.edit(path)
end

function M:get_pin_for_current_file()
    local filename = self:get_current_filename()

    local pin_for_current_file
    for _, pin in ipairs(self.state.pins) do
        if pin.filename == filename then
            pin_for_current_file = pin
        else
            pin_for_current_file = nil
        end
    end
    return pin_for_current_file
end

---@param path string
---@return string
function M:get_formatted_filepath(path)
    return vim.fn.fnamemodify(path, self.config.path_format)
end

---Create formatted pin entries from pins
---@param pins Pin[]
---@return string[] -- ATTENTION: This does NOT generate a new array of objects, but just an array of strings
function M:create_entries(pins)
    local entries = {}

    for _, p in ipairs(pins) do
        local path = vim.fn.fnamemodify(p.filename, self.config.path_format)
        local entry = string.format("  [%s] %s  ", p.label, path)
        table.insert(entries, entry)
    end

    return entries
end

function M:get_board_bufid()
    local win = self.state.pin_board_win

    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        return vim.api.nvim_win_get_buf(win)
    else
        return nil
    end
end

function M:create_board()
    local entries = M:create_entries(self.state.pins)

    local new_buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(new_buf_id, 0, -1, false, entries)

    local board_width = self.config.win.width
    local win_opts = vim.tbl_deep_extend("force", self.config.win, {
        width = board_width,
        height = #entries,
        -- row = math.floor((vim.o.lines - #entries) - 10),
        row = 1,
        col = math.floor((vim.o.columns - board_width) - 2),
    })

    local win = vim.api.nvim_open_win(new_buf_id, false, win_opts)
    M.state.pin_board_win = win
end

function M:highlight_active_pin()
    local pin_board_buf_id = self:get_board_bufid()

    if pin_board_buf_id == nil then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(pin_board_buf_id, 0, -1, false)

    local curr_filepath = self:get_current_filename()
    local curr_formatted_filepath = self:get_formatted_filepath(curr_filepath)

    -- Abort on empty files
    if curr_formatted_filepath == "" then
        return
    end

    vim.api.nvim_buf_clear_namespace(pin_board_buf_id, self.constants.ns_mini_win, 0, -1)

    for i, line in ipairs(lines) do
        if line:find(curr_formatted_filepath, 1, true) then
            vim.api.nvim_buf_set_extmark(pin_board_buf_id, self.constants.ns_mini_win, i - 1, 0, {
                end_col = #line,
                hl_group = "@function",
            })
            break
        end
    end
end

function M:update_board()
    local pin_board_buf_id = self:get_board_bufid()
    if pin_board_buf_id == nil then
        return
    end

    local entries = M:create_entries(self.state.pins)

    vim.api.nvim_buf_set_lines(pin_board_buf_id, 0, -1, false, entries)
    vim.api.nvim_win_set_config(self.state.pin_board_win, {
        relative = "editor",
        height = #self.state.pins,
        row = 1,
        col = math.floor((vim.o.columns - self.config.win.width) - 2),
    })
end

---@param opts Radar.Config
function M.setup(opts)
    opts = opts or {}
    local merged_config = vim.tbl_deep_extend("force", M.config, opts)
    M.config = merged_config

    vim.keymap.set("n", M.config.keys.lock, M.pin, { desc = "Pin the current buffer" })

    vim.keymap.set("n", ";q", function()
        vim.api.nvim_win_close(M.state.pin_board_win, true)
    end, { desc = "Close Pins" })

    for _, label in ipairs(M.config.keys) do
        vim.keymap.set("n", M.config.keys.prefix .. label, function()
            M:open_pin(label)
            M:highlight_active_pin()
        end, { desc = "Open " .. label .. " Pin" })
    end

    M:populate()

    _G.Pins = M
end

return M
