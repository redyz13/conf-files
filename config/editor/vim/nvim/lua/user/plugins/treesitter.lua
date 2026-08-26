local ensure_installed = {
  "c",
  "lua",
  "vim",
  "vimdoc",
  "query",
  "cpp",
  "java",
  "python",
  "bash",
  "markdown",
  "markdown_inline",
}

return {
  "nvim-treesitter/nvim-treesitter",
  name = "treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")

    -- Install the parsers synchronously.
    treesitter.install(ensure_installed):wait(300000)

    vim.cmd("syntax enable")

    local group = vim.api.nvim_create_augroup("treesitter_highlight", {
      clear = true,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        local max_filesize = 100 * 1024
        local ok, stats = pcall(
          vim.uv.fs_stat,
          vim.api.nvim_buf_get_name(args.buf)
        )

        if ok and stats and stats.size > max_filesize then
          return
        end

        local language = vim.treesitter.language.get_lang(args.match)

        if not language or not vim.treesitter.language.add(language) then
          return
        end

        vim.treesitter.start(args.buf, language)
      end,
    })
  end,
}
