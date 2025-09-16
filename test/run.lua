-- Test runner for radar.nvim using mini.test

-- Add project root to runtime path
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)

-- Add mini.nvim to runtime path (assuming it's installed via lazy.nvim)
local mini_path = vim.fn.stdpath("data") .. "/lazy/mini.nvim"
if vim.fn.isdirectory(mini_path) == 1 then
  vim.opt.rtp:prepend(mini_path)
else
  error("mini.nvim not found. Please ensure it's installed.")
end

-- Load and setup mini.test
local ok, mini_test = pcall(require, "mini.test")
if not ok then
  error("Failed to load mini.test: " .. tostring(mini_test))
end

mini_test.setup({
  -- Enable busted-style syntax (describe, it, etc.)
  collect = {
    emulate_busted = true,
    -- Find all test files in test/spec directory
    find_files = function()
      local test_dir = root .. "/test/spec"
      local files = {}

      -- Simple recursive file finder
      local function find_lua_files(dir)
        local handle = vim.loop.fs_scandir(dir)
        if not handle then
          return
        end

        local name, type = vim.loop.fs_scandir_next(handle)
        while name do
          local full_path = dir .. "/" .. name
          if type == "file" and name:match("%.lua$") then
            table.insert(files, full_path)
          elseif type == "directory" then
            find_lua_files(full_path)
          end
          name, type = vim.loop.fs_scandir_next(handle)
        end
      end

      find_lua_files(test_dir)
      return files
    end,
  },
  -- Configure reporter based on whether we're in headless mode
  execute = {
    reporter = mini_test.gen_reporter.stdout(),
  },
})

-- Run the tests
local function run_tests()
  -- Check if a specific file is requested
  local args = vim.v.argv
  local specific_file = nil

  for i, arg in ipairs(args) do
    if arg == "--file" and args[i + 1] then
      specific_file = root .. "/" .. args[i + 1]
      break
    end
  end

  if specific_file then
    -- Run specific file
    mini_test.run_file(specific_file)
  else
    -- Run all tests
    mini_test.run()
  end

  -- Exit with appropriate code based on test results
  vim.defer_fn(function()
    -- Check test results and exit with appropriate code
    local stats = mini_test.current and mini_test.current.all_cases_stats
    if stats and stats.fail and stats.fail > 0 then
      vim.cmd("cquit 1") -- Exit with error code
    else
      vim.cmd("quit 0") -- Exit successfully
    end
  end, 500)
end

-- Run tests immediately
run_tests()
