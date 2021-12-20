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

set noswapfile
set nobackup
set undodir=~/.config/nvim/undodir
set undofile

let mapleader = ","

inoremap " ""<left>
inoremap ' ''<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap {<CR> {<CR>}<ESC>O
inoremap {;<CR> {<CR>};<ESC>O

" Disable expandtab for Makefiles
autocmd FileType make setlocal noexpandtab

" Plugins
call plug#begin()
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    Plug 'itchyny/lightline.vim'
    Plug 'preservim/nerdtree'
    Plug 'ryanoasis/vim-devicons' " Requires a supported font
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'tpope/vim-fugitive'
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

" Keys
" gt = next tab
" gT = previous tab

" Find files using Telescope command-line sugar.
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" Using Lua functions
"nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
"nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
"nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
"nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
