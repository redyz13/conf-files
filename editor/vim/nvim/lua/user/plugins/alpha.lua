return {
  'goolord/alpha-nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  name = "alpha-nvim",
  config = function ()
    require'alpha'.setup(require'alpha.themes.dashboard'.config)

    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      [[  ／|_       ]],
      [[ (o o /      ]],
      [[  |.   ~.    ]],
      [[  じしf_,)ノ ]],
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "󰈞  Find file", ":Telescope find_files <CR>"),
      dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
      dashboard.button("p", "  Find project", ":Telescope projects <CR>"),
      dashboard.button("r", "󰄉  Recently used files", ":Telescope oldfiles <CR>"),
      dashboard.button("t", "󰊄  Find text", ":Telescope live_grep <CR>"),
      dashboard.button("c", "  Configuration", ":e ~/.config/nvim/init.lua <CR>"),
      dashboard.button("q", "󰅚  Quit Neovim", ":qa<CR>"),
    }

    local function footer()
      -- NOTE: requires the fortune-mod package to work
      -- local handle = io.popen("fortune")
      -- local fortune = handle:read("*a")
      -- handle:close()
      -- return fortune
      return "redyz <3"
    end

    dashboard.section.footer.val = footer()

    dashboard.section.footer.opts.hl = "Type"
    dashboard.section.header.opts.hl = "Include"
    dashboard.section.buttons.opts.hl = "Keyword"

    dashboard.opts.opts.noautocmd = true
    -- vim.cmd([[autocmd User AlphaReady echo 'ready']])
    require("alpha").setup(dashboard.opts)
  end
};
