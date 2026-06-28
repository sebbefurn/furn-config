" ~/.vimrc — managed by furn-config (stow vim).
" Zero plugins, with one deliberate exception: vim-tmux-navigator
" (installed as a native package at ~/.vim/pack/plugins/start/).

set nocompatible
filetype plugin indent on
syntax on

" ---- Colors: vendored gruvbox (hard contrast), fall back to retrobox ----
set background=dark
if has('termguicolors')
  set termguicolors
endif
let g:gruvbox_contrast_dark = 'hard'  " darker bg0_h (#1d2021); set before colorscheme
silent! colorscheme gruvbox
if !exists('g:colors_name') || g:colors_name !=# 'gruvbox'
  silent! colorscheme retrobox        " built-in, gruvbox-like
endif

" ---- Sane defaults ----
set number relativenumber
set hidden
set mouse=a
set clipboard=unnamedplus
set expandtab shiftwidth=2 softtabstop=2 tabstop=2 shiftround
set autoindent smartindent
set ignorecase smartcase incsearch hlsearch
set wildmenu wildmode=longest:full,full
set path+=**                          " :find fuzzy across the tree
set scrolloff=4 sidescrolloff=8
set splitbelow splitright
set updatetime=300
set laststatus=2 ruler showcmd
set list listchars=tab:»·,trail:·,nbsp:␣
set timeoutlen=500 ttimeoutlen=10
set undofile undodir=~/.vim/undo
set backupdir=~/.vim/backup directory=~/.vim/swap

" ---- netrw file browser (built-in) ----
let g:netrw_banner=0
let g:netrw_liststyle=3
let g:netrw_winsize=25

" ---- Leader maps ----
let mapleader=' '
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>e :Explore<CR>
nnoremap <leader>f :find
nnoremap <leader>b :buffers<CR>:buffer<Space>
nnoremap <leader>/ :nohlsearch<CR>
inoremap jk <Esc>

" ---- Create runtime dirs ----
for s:d in ['undo','backup','swap']
  if !isdirectory(expand('~/.vim/'.s:d))
    call mkdir(expand('~/.vim/'.s:d), 'p')
  endif
endfor
