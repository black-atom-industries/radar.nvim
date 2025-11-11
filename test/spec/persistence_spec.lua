local persistence = require("radar.persistence")

describe("persistence", function()
  local test_data_path = vim.fn.tempname() .. ".json"
  local test_config = {
    persist = {
      path = test_data_path,
    },
  }

  after_each(function()
    -- Clean up test file
    vim.fn.delete(test_data_path)
  end)

  describe("deterministic JSON output", function()
    it("should produce identical output for identical data", function()
      -- Create test data
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/project-a"] = {
            ["branch-1"] = {
              locks = {
                { filename = "file1.lua", label = "1" },
                { filename = "file2.lua", label = "2" },
              },
              lastAccessed = 1234567890,
            },
          },
          ["~/repos/project-b"] = {
            ["main"] = {
              locks = {
                { filename = "readme.md", label = "1" },
              },
              lastAccessed = 1234567891,
            },
          },
        },
      }

      -- Write data twice
      persistence.write(test_data_path, test_data)
      vim.wait(2500) -- Wait for jq to finish
      local first_output = vim.fn.readfile(test_data_path)

      persistence.write(test_data_path, test_data)
      vim.wait(2500) -- Wait for jq to finish
      local second_output = vim.fn.readfile(test_data_path)

      -- Compare line by line
      MiniTest.expect.equality(#first_output, #second_output)
      for i = 1, #first_output do
        MiniTest.expect.equality(first_output[i], second_output[i])
      end
    end)

    it("should have consistent property order in branch data", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/test"] = {
            ["main"] = {
              locks = {},
              lastAccessed = 1234567890,
            },
          },
        },
      }

      persistence.write(test_data_path, test_data)
      vim.wait(2500)
      local lines = vim.fn.readfile(test_data_path)
      local content = table.concat(lines, "\n")

      -- Check that "lastAccessed" comes after "locks"
      local locks_pos = content:find('"locks"', 1, true)
      local accessed_pos = content:find('"lastAccessed"', 1, true)

      MiniTest.expect.truthy(locks_pos)
      MiniTest.expect.truthy(accessed_pos)
      MiniTest.expect.truthy(locks_pos < accessed_pos)
    end)

    it("should have consistent property order in lock objects", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/test"] = {
            ["main"] = {
              locks = {
                { filename = "test.lua", label = "1" },
              },
              lastAccessed = 1234567890,
            },
          },
        },
      }

      persistence.write(test_data_path, test_data)
      vim.wait(2500)
      local lines = vim.fn.readfile(test_data_path)

      -- Find the lock object and check property order
      local found_filename = false
      local found_label = false
      local filename_line = 0
      local label_line = 0

      for i, line in ipairs(lines) do
        if line:find('"filename"', 1, true) then
          found_filename = true
          filename_line = i
        end
        if line:find('"label"', 1, true) and not found_label then
          found_label = true
          label_line = i
        end
      end

      MiniTest.expect.truthy(found_filename)
      MiniTest.expect.truthy(found_label)
      MiniTest.expect.truthy(filename_line < label_line)
    end)

    it("should keep projects in alphabetical order", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/zebra"] = { main = { locks = {}, lastAccessed = 1 } },
          ["~/repos/alpha"] = { main = { locks = {}, lastAccessed = 2 } },
          ["~/repos/beta"] = { main = { locks = {}, lastAccessed = 3 } },
        },
      }

      persistence.write(test_data_path, test_data)
      vim.wait(2500)
      local lines = vim.fn.readfile(test_data_path)
      local content = table.concat(lines, "\n")

      -- Check alphabetical order
      local alpha_pos = content:find("~/repos/alpha", 1, true)
      local beta_pos = content:find("~/repos/beta", 1, true)
      local zebra_pos = content:find("~/repos/zebra", 1, true)

      MiniTest.expect.truthy(alpha_pos)
      MiniTest.expect.truthy(beta_pos)
      MiniTest.expect.truthy(zebra_pos)
      MiniTest.expect.truthy(alpha_pos < beta_pos)
      MiniTest.expect.truthy(beta_pos < zebra_pos)
    end)
  end)
end)
