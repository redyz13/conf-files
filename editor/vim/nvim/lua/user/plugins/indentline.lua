return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  name = "indent-line",
  config = function()
    require("ibl").setup({
      indent = {
        char = "▏",
      },
      scope = {
        enabled = true,
        show_start = true,
      },
      exclude = {
        buftypes = { "terminal", "nofile" },
        filetypes = {
          "help",
          "startify",
          "dashboard",
          "packer",
          "neogitstatus",
          "NvimTree",
          "Trouble",
          "markdown",
        },
      },
    })

    -- HACK: work-around for https://github.com/lukas-reineke/indent-blankline.nvim/issues/59
    vim.wo.colorcolumn = "99999"
  end
}

