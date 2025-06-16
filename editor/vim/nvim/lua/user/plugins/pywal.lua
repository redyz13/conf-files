return {
  "AlphaTechnolog/pywal.nvim",
  name = "pywal",
  lazy = false,
  priority = 1001,
  config = function()
    if vim.g.my_colorscheme ~= "pywal" then return end
    require("pywal").setup()
    vim.cmd("colorscheme pywal")
  end
}

