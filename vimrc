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

inoremap " ""<left>
inoremap ' ''<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap {<CR> {<CR>}<ESC>O
inoremap {;<CR> {<CR>};<ESC>O

if &term =~ "tmux"                                                   
    let &t_BE = "\e[?2004h"                                              
    let &t_BD = "\e[?2004l"                                              
    exec "set t_PS=\e[200~"                                              
    exec "set t_PE=\e[201~"                                              
endif

autocmd FileType make setlocal noexpandtab

packadd! dracula
colorscheme dracula
hi Normal guibg=NONE ctermbg=NONE

" Install vim-gtk in order to copy to clipboard
" "+y
