return {
  'uZer/pywal16.nvim',
  name = 'pywal',
  lazy = false, 
  priority = 1001,
  config = function()
    if vim.g.my_colorscheme ~= "pywal16" then return end
    require('pywal16').setup()
    vim.cmd('colorscheme pywal16')

    local function apply_style(pattern, style)
      for _, group in ipairs(vim.fn.getcompletion('', 'highlight')) do
        if string.match(string.lower(group), pattern) then
          vim.cmd(string.format('highlight %s gui=%s cterm=%s', group, style, style))
        end
      end
    end

    apply_style('keyword', 'bold')
    apply_style('statement', 'bold')
    apply_style('function', 'italic')
    apply_style('comment', 'italic')
    apply_style('type', 'italic')
    apply_style('parameter', 'italic')
  end
}

