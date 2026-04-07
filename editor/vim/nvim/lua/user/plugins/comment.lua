return {
  "numToStr/Comment.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  config = function()
    local comment = require("Comment")

    local ts_pre_hook =
      require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()

    comment.setup({
      pre_hook = function(ctx)
        local ok, res = pcall(ts_pre_hook, ctx)
        if ok and res then
          return res
        end
        return vim.bo.commentstring
      end,
    })
  end,
}
