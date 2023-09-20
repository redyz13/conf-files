return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    vim.opt.termguicolors = true

    vim.g.nvim_tree_icons = {
      default = "",
      symlink = "",
      git = {
        unstaged = "",
        staged = "S",
        unmerged = "",
        renamed = "➜",
        deleted = "",
        untracked = "U",
        ignored = "◌",
      },
      folder = {
        arrow_open = " ",
        arrow_closed = "",
        default = "",
        open = "",
        empty = "",
        empty_open = "",
        symlink = "",
      },
    }

    require("nvim-tree").setup({
      hijack_cursor = true,
      update_cwd = true,
      view = {
        width = 30,
        hide_root_folder = false,
        side = "left",
        number = false,
        relativenumber = false,
      },
      diagnostics = {
        enable = true,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = {},
      },
      git = {
        enable = true,
        ignore = true,
        timeout = 500,
      },
      renderer = {
        indent_markers = {
          enable = true
        },
        -- icons = {
        --   glyphs = {
        --     folder = {
        --       -- arrow_closed = "", -- arrow when folder is closed
        --       -- arrow_open = "", -- arrow when folder is open
        --     },
        --   },
        -- },
      },
      actions = {
        open_file = {
          window_picker = {
            enable = false,
          },
        },
      },
      filters = {
        custom = { ".DS_Store" },
      },
    })

    vim.keymap.set("n", "<leader>e", "<Cmd>NvimTreeToggle<CR>")
  end,
}
