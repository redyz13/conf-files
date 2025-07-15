return {
  'uZer/pywal16.nvim',
  name = 'pywal',
  lazy = false, 
  priority = 1001,
  config = function()
    if vim.g.my_colorscheme ~= "pywal16" then return end
    require('pywal16').setup()
    vim.cmd('colorscheme pywal16')
  end
}

