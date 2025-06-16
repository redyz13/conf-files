return {
    'nvimdev/lspsaga.nvim',
    name = "lspsaga",
    dependencies = {
        'nvim-treesitter/nvim-treesitter', -- optional
        'nvim-tree/nvim-web-devicons',     -- optional
    },
    config = function()
        require('lspsaga').setup({
          ui = {
            kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind(),
          },
          symbol_in_winbar = {
            folder_level = 2,
          },
        })
    end
}

