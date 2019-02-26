" reset augroup
augroup vimrc
  autocmd!
augroup END

" ================================================== dein setting ==================================================
" プラグインが実際にインストールされるディレクトリ
let s:dein_dir = expand('~/.config/dein')

let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif

  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  if !has('nvim')
    let g:vimrc_dir = expand($HOME . '/.config/vim')
    let s:vim_lazy_toml  = g:vimrc_dir . '/dein_lazy.toml'

    call dein#load_toml(s:vim_lazy_toml, {'lazy': 1})
  endif

  let g:rc_dir = expand($HOME . '/.config/dein')

  let s:toml             = g:rc_dir . '/dein.toml'
  let s:lazy_toml        = g:rc_dir . '/dein_lazy.toml'

  call dein#load_toml(s:toml,      {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
if dein#check_install()
  call dein#install()
endif
" ==================================================================================================================


" ================================================== General Settings ==================================================
let g:python_host_prog = '/usr/local/bin/python'
let g:python3_host_prog = '/usr/local/bin/python3'

filetype plugin indent on
syntax enable

"文字コードをUFT-8に設定
set fenc=utf-8
" バックアップファイルを作らない
set nobackup
" スワップファイルを作らない
set noswapfile
" 編集中のファイルが変更されたら自動で読み直す
set autoread
" バッファが編集中でもその他のファイルを開けるように
set hidden
" 入力中のコマンドをステータスに表示する
set showcmd
" 保存時に余計なスペースを削除
autocmd BufWritePre * :%s/\s\+$//ge

" 現在の行を強調表示
set cursorline
" 行末の1文字先までカーソルを移動できるように
set virtualedit=onemore
" インデントはスマートインデント
set smartindent
set noautoindent

" ステータスラインを常に表示
set laststatus=2
" コマンドラインの補完
set wildmenu
set wildmode=full
" 補完メニューの高さ
set pumheight=10
" 長い行があった場合
set display=lastline

syntax on

" Tab系
" 不可視文字を可視化(タブが「▸-」と表示される)
set list listchars=tab:\▸\-
" Tab文字を半角スペースにする
set expandtab
" 行頭以外のTab文字の表示幅（スペースいくつ分）
set tabstop=2
" 行頭でのTab文字の表示幅
set shiftwidth=2

augroup fileTypeIndent
    autocmd!
    autocmd BufNewFile,BufRead *.py setlocal tabstop=4 softtabstop=4 shiftwidth=4
    autocmd BufNewFile,BufRead *.rb setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd BufNewFile,BufRead *.java setlocal tabstop=4 softtabstop=4 shiftwidth=4
    autocmd BufNewFile,BufRead *.php setlocal tabstop=4 softtabstop=4 shiftwidth=4
    autocmd BufNewFile,BufRead *.jl setlocal tabstop=4 softtabstop=4 shiftwidth=4
augroup END

" ファイルの認識系
autocmd BufNewFile,BufRead *.jbuilder setfiletype ruby
autocmd BufNewFile,BufRead Guardfile  setfiletype ruby
autocmd BufNewFile,BufRead .pryrc     setfiletype ruby
autocmd BufNewFile,BufRead *.md       setfiletype markdown
autocmd BufNewFile,BufRead *.slim     setfiletype slim
autocmd BufNewFile,BufRead *.nim      setfiletype nim
autocmd BufNewFile,BufRead *.jl       setfiletype julia
autocmd BufNewFile,BufRead *.tsx,*jsx setfiletype typescript.tsx

" 検索系
" 検索文字列が小文字の場合は大文字小文字を区別なく検索する
set ignorecase
" 検索文字列に大文字が含まれている場合は区別して検索する
set smartcase
" 検索文字列入力時に順次対象文字列にヒットさせる
set incsearch
" 検索時に最後まで行ったら最初に戻る
set wrapscan
" 検索語をハイライト表示
set hlsearch
" ESC連打でハイライト解除
nmap <Esc><Esc> :nohlsearch<CR><Esc>

" クリップボードにコピー
set clipboard+=unnamed

set background=dark
colorscheme apprentice
" Deniteのカラーがおかしい
hi CursorLine guifg=#E19972

" 置換の時に大活躍
if has('nvim')
  set inccommand=split
else " vimの設定
  " 挿入モード時に非点滅の縦棒タイプのカーソル
  let &t_SI .= "\e[6 q"
  " ノーマルモード時に非点滅のブロックタイプのカーソル
  let &t_EI .= "\e[2 q"
  " 置換モード時に非点滅の下線タイプのカーソル
  let &t_SR .= "\e[4 q"
endif
" ==================================================================================================================


" ================================================== Key Mapping ==================================================
" leaderの登録
let mapleader = "\<space>"
let maplocalleader = ","

" ヤンクの設定
nnoremap Y y$

" バッファ移動の設定
nnoremap ]b :bn<CR>
nnoremap ]B :blast<CR>
nnoremap [b :bp<CR>
nnoremap [B :bfirst<CR>

" 折り返し時に表示行単位での移動できるようにする
nnoremap j gj
nnoremap k gk

" escキーをjjに登録
inoremap <silent> jj <ESC>

" '%%'でアクティブなバッファのディレクトリを開いてくれる
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'

tnoremap <silent> jj <C-\><C-n>
" ==================================================================================================================
