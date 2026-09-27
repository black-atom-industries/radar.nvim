local alternative = require("radar.data.alternative")

describe("alternative", function()
  local original_expand

  before_each(function()
    original_expand = vim.fn.expand
  end)

  after_each(function()
    vim.fn.expand = original_expand
  end)

  it("returns nil when there is no alternate buffer", function()
    vim.fn.expand = function(expression)
      if expression == "#" then
        error("Vim:E194: No alternate file name to substitute for '#'")
      end
      return original_expand(expression)
    end

    MiniTest.expect.equality(alternative.get_alternative_file(), nil)
  end)
end)
