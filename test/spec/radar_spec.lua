local radar = require("radar.ui.radar")

describe("radar path formatting", function()
  it("shows the current Oil directory as ./", function()
    local oil_url = "oil://" .. vim.uv.cwd() .. "/"

    MiniTest.expect.equality(radar.get_formatted_filepath(oil_url), "./")
  end)

  it("shows Oil subdirectories relative to cwd with a trailing slash", function()
    local oil_url = "oil://" .. vim.uv.cwd() .. "/lua/radar/"

    MiniTest.expect.equality(radar.get_formatted_filepath(oil_url), "lua/radar/")
  end)

  it("leaves other protocol URLs on the existing formatting path", function()
    local filename = "gh://owner/repo/blob/main/file.lua"

    MiniTest.expect.equality(
      radar.get_formatted_filepath(filename),
      vim.fn.fnamemodify(filename, ":p:.")
    )
  end)
end)
