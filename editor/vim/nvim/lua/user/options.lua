vim.g.my_colorscheme = "pywal16"

local options = {
  undofile = true,                         -- enable persistent undo
  backup = false,                          -- creates a backup file
  -- clipboard = "unnamedplus",            -- allows neovim to access the system clipboard
  -- cmdheight = 2,                        -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  conceallevel = 0,                        -- so that `` is visible in markdown files
  fileencoding = "utf-8",                  -- the encoding written to a file
  hlsearch = false,                        -- highlight all matches on previous search pattern
  ignorecase = true,                       -- ignore case in search patterns
  mouse = "",                              -- disable mouse
  pumheight = 10,                          -- pop up menu height
  showmode = false,                        -- show mode (insert, normal, etc.)
  showtabline = 2,                         -- always show tabs
  splitbelow = true,                       -- force all horizontal splits to go below current window
  splitright = true,                       -- force all vertical splits to go to the right of current window
  swapfile = false,                        -- creates a swapfile
  termguicolors = true,                    -- set term gui colors (most terminals support this)
  -- timeoutlen = 300,                     -- time to wait for a mapped sequence to complete (in milliseconds)
  updatetime = 300,                        -- faster completion (4000ms default)
  writebackup = false,                     -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  expandtab = true,                        -- convert tabs to spaces
  shiftwidth = 2,                          -- the number of spaces inserted for each indentation
  tabstop = 2,                             -- insert 2 spaces for a tab
  softtabstop = 2,
  smartindent = true,
  smartcase = true,
  incsearch = true,
  scrolloff = 8,
  sidescrolloff = 8,
  cursorline = true,                       -- highlight the current line
  number = true,                           -- set numbered lines
  relativenumber = true,                   -- set relative numbered lines
  numberwidth = 4,                         -- set number column width {default 4}
  signcolumn = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  wrap = false,                            -- display lines as one long line
  guifont = "monospace:h17",               -- the font used in graphical neovim applications
  autochdir = true,                        -- set working directory to current file automatically
  backspace = "indent,eol,start",
}

vim.opt.shortmess:append "c"

for k, v in pairs(options) do
  vim.opt[k] = v
end

vim.cmd "set whichwrap+=<,>,[,],h,l"
vim.cmd [[set iskeyword+=-]]
vim.cmd [[set formatoptions-=cro]]
