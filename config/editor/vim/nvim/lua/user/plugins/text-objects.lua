return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        -- Automatically jump forward to textobj, similar to targets.vim
        lookahead = true,
        include_surrounding_whitespace = true,
      },
    })

    local select = require("nvim-treesitter-textobjects.select")
    local swap = require("nvim-treesitter-textobjects.swap")

    local function map_textobject(key, query, desc)
      vim.keymap.set({ "x", "o" }, key, function()
        select.select_textobject(query, "textobjects")
      end, {
        desc = desc,
      })
    end

    map_textobject("a=", "@assignment.outer", "Select outer part of an assignment region")
    map_textobject("i=", "@assignment.inner", "Select inner part of an assignment region")
    map_textobject("a:", "@parameter.outer", "Select outer part of a parameter/field region")
    map_textobject("i:", "@parameter.inner", "Select inner part of a parameter/field region")

    map_textobject("ai", "@conditional.outer", "Select outer part of a conditional region")
    map_textobject("ii", "@conditional.inner", "Select inner part of a conditional region")
    map_textobject("al", "@loop.outer", "Select outer part of a loop region")
    map_textobject("il", "@loop.inner", "Select inner part of a loop region")

    map_textobject("ab", "@block.outer", "Select outer part of a block region") -- Overrides default text object block of parenthesis to parenthesis
    map_textobject("ib", "@block.inner", "Select inner part of a block region") -- Overrides default text object block of parenthesis to parenthesis

    map_textobject("af", "@function.outer", "Select outer part of a function region")
    map_textobject("if", "@function.inner", "Select inner part of a function region")
    map_textobject("ac", "@class.outer", "Select outer part of a class region")
    map_textobject("ic", "@class.inner", "Select inner part of a class region")

    vim.keymap.set("n", "<leader>on", function()
      swap.swap_next("@parameter.inner")
    end) -- Swap object under cursor with next

    vim.keymap.set("n", "<leader>op", function()
      swap.swap_previous("@parameter.inner")
    end) -- Swap object under cursor with previous
  end,
}
