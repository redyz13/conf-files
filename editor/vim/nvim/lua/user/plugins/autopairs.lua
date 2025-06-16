return {
    'windwp/nvim-autopairs',
    name = "auto-pairs",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/nvim-cmp",
    },
    opts = {
      pre_hook = function(ctx)
        local U = require "Comment.utils"

        local location = nil
        if ctx.ctype == U.ctype.block then
          location = require("ts_context_commentstring.utils").get_cursor_location()
        elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
          location = require("ts_context_commentstring.utils").get_visual_start_location()
        end

        return require("ts_context_commentstring.internal").calculate_commentstring {
          key = ctx.ctype == U.ctype.line and "__default" or "__multiline",
          location = location,
        }
      end,
    }, --Tthis is equalent to setup({}) function
    config = function()
      -- Import nvim-autopairs
      local autopairs = require("nvim-autopairs")

      -- Configure autopairs
      autopairs.setup({
        check_ts = true, -- Enable treesitter
        ts_config = {
          lua = { "string" }, -- Don't add pairs in lua string treesitter nodes
          javascript = { "template_string" }, -- Don't add pairs in javscript template_string treesitter nodes
        },
      })

      -- Import nvim-autopairs completion functionality
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")

      -- Import nvim-cmp
      local cmp = require("cmp")

      -- Make autopairs and completion work together
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

    end
}
