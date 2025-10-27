return {
  'uZer/pywal16.nvim',
  name = 'pywal',
  lazy = false,
  priority = 1001,
  config = function()
    if vim.g.my_colorscheme ~= "pywal16" then return end
    require('pywal16').setup()
    vim.cmd('colorscheme pywal16')

    local function fix_keywords()
      local kw = vim.api.nvim_get_hl(0, { name = 'Keyword', link = false })
      if not kw then return end
      vim.api.nvim_set_hl(0, 'Keyword', vim.tbl_extend('force', kw, { bold = true, cterm = { bold = true } }))
      vim.api.nvim_set_hl(0, 'Conditional', { link = 'Keyword' })
      vim.api.nvim_set_hl(0, '@keyword.conditional', { link = 'Keyword' })
    end

    fix_keywords()

    local function apply_style(pattern, style)
      for _, group in ipairs(vim.fn.getcompletion('', 'highlight')) do
        if string.match(string.lower(group), pattern) then
          vim.cmd(string.format('highlight %s gui=%s cterm=%s', group, style, style))
        end
      end
    end

    apply_style('function',  'italic')
    apply_style('comment',   'italic')
    apply_style('type',      'italic')
    apply_style('parameter', 'italic')

    vim.api.nvim_create_autocmd({ 'ColorScheme', 'BufEnter', 'FileType' }, {
      callback = function()
        if vim.g.colors_name == 'pywal16' then
          vim.schedule(fix_keywords)
        end
      end
    })
  end
}

