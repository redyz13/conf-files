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

" Plugins
call plug#begin()
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    Plug 'itchyny/lightline.vim'
    Plug 'preservim/nerdtree'
    Plug 'ryanoasis/vim-devicons' " Requires a supported font
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'tpope/vim-fugitive'
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    Plug 'jiangmiao/auto-pairs'
call plug#end()

" Color scheme
packadd! dracula
colorscheme dracula
hi Normal guibg=NONE ctermbg=NONE

" Transparent vertical split bar
highlight VertSplit ctermbg=NONE ctermfg=NONE cterm=NONE

" Install vim-gtk in order to copy to clipboard
" "+y

" Only if you're using tmux 
if &term =~ "tmux"                                                   
    let &t_BE = "\e[?2004h"                                              
    let &t_BD = "\e[?2004l"                                              
    exec "set t_PS=\e[200~"                                              
    exec "set t_PE=\e[201~"                                              
endif

" Lightline configuration
set laststatus=2
set noshowmode

let g:lightline = {
      \ 'colorscheme': 'darcula',
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

" Nerdtree configuration
nnoremap <C-n> :NERDTree ~/<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>
let NERDTreeShowHidden=1
let NERDTreeQuitOnOpen=1

" Telescope config

" Find files using Telescope command-line sugar.
"nnoremap <leader>ff <cmd>Telescope find_files<cr>
"nnoremap <leader>fg <cmd>Telescope live_grep<cr>
"nnoremap <leader>fb <cmd>Telescope buffers<cr>
"nnoremap <leader>fh <cmd>Telescope help_tags<cr>
"nnoremap <leader>fo <cmd>Telescope oldfiles<cr>
"nnoremap <leader>fi <cmd>Telescope file_browser<cr>

" Using Lua functions
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
nnoremap <leader>fo <cmd>lua require('telescope.builtin').oldfiles()<cr>
nnoremap <leader>fi <cmd>lua require('telescope.builtin').file_browser()<cr>

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
