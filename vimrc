syntax on
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
set undodir=~/.vim/undodir
set undofile

let mapleader = " "

inoremap " ""<left>
inoremap ' ''<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap {<CR> {<CR>}<ESC>O
inoremap {;<CR> {<CR>};<ESC>O

" Disable expandtab for Makefiles
autocmd FileType make setlocal noexpandtab

" Color scheme
packadd! dracula
colorscheme dracula
hi Normal guibg=NONE ctermbg=NONE

" Install vim-gtk in order to copy to clipboard
" "+y

" Only if you're using tmux 
if &term =~ "tmux"                                                   
    let &t_BE = "\e[?2004h"                                              
    let &t_BD = "\e[?2004l"                                              
    exec "set t_PS=\e[200~"                                              
    exec "set t_PE=\e[201~"                                              
endif

" Plugins
call plug#begin('~/.vim/plugged')
Plug 'itchyny/lightline.vim'
Plug 'preservim/nerdtree'
Plug 'ryanoasis/vim-devicons' " Requires a supported font
Plug 'Xuyuanp/nerdtree-git-plugin'
call plug#end()

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
      \ }

" Nerdtree configuration
nnoremap <C-n> :NERDTree ~/<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>
let NERDTreeShowHidden=1

" Keys
" gt = next tab
" gT = previous tab
