syntax on
set nohlsearch
set noerrorbells
set tabstop=4 softtabstop=4
set shiftwidth=4
set expandtab
set smartindent
set nowrap
set smartcase
set incsearch
set number
set background=dark
set relativenumber
set scrolloff=8
set splitright

set noswapfile
set nobackup
set undodir=~/.config/nvim/undodir
set undofile

" Set working directory to current file automatically
set autochdir

let mapleader = " "

" Disable expandtab for Makefiles
autocmd FileType make setlocal noexpandtab

" Disable line numbers in terminal mode
autocmd TermOpen * setlocal nonumber norelativenumber

" Open terminal shortcut
nnoremap <leader>tt :term<CR>

" Exit insert mode in terminal with Esc key
tnoremap <Esc> <C-\><C-N>

" Clipboard access
set clipboard+=unnamedplus

" Plugins
call plug#begin()
    Plug 'itchyny/lightline.vim'
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    Plug 'jiangmiao/auto-pairs'
    Plug 'numToStr/Comment.nvim'
    " Plug 'https://gitlab.com/__tpb/monokai-pro.nvim'
    Plug 'olimorris/onedarkpro.nvim'
call plug#end()

" Color scheme
colorscheme onedarkpro
hi Normal guibg=NONE ctermbg=NONE
highlight LineNr ctermfg=grey

" Transparent vertical split bar
highlight VertSplit ctermbg=NONE ctermfg=NONE cterm=NONE

" Comment
lua require('Comment').setup()

" Lightline configuration
set laststatus=2
set noshowmode

let g:lightline = {
      \ 'colorscheme': 'one',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'readonly', 'filename', 'modified', 'helloworld' ] ]
      \ },
      \ 'component': {
      \   'helloworld': 'redyz <3'
      \ },
      \ 'enable': {
      \   'tabline': 0
      \ },
      \}

" Treesitter configurationon
" :TSInstall <language_to_install> (C is installed)
" :TSUpdate to update

lua << EOF
require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false,
    },

    indent = {
        enable = true
    }
}
EOF
