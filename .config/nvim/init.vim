" reset augroup
augroup vimrc
  autocmd!
augroup END

" プラグインが実際にインストールされるディレクトリ
if has('nvim')
  let s:dein_dir = expand('~/.config/nvim/dein')
else
  let s:dein_dir = expand('~/.config/vim/dein')
endif

" dein.vim 本体
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

" dein.vim がなければ github から落としてくる
if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif

  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

" 設定開始
if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " プラグインリストを収めた TOML ファイル
  " 予め TOML ファイル（後述）を用意しておく
  if has('nvim')
    let g:rc_dir = expand('~/.config/nvim')
  else
    let g:rc_dir = expand('~/.config/vim')
  endif

  let s:toml             = g:rc_dir . '/dein.toml'
  let s:lazy_toml        = g:rc_dir . '/dein_lazy.toml'

  " TOML を読み込み、キャッシュしておく
  if exists('g:nyaovim_version')
    call dein#load_toml('~/.config/nyaovim/dein.toml', {'lazy': 1})
  endif

  call dein#load_toml(s:toml,          {'lazy': 0})
  call dein#load_toml(s:lazy_toml,     {'lazy': 1})

  " 設定終了
  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
if dein#check_install()
  call dein#install()
endif

filetype plugin indent on
syntax enable

" setting
" leaderの登録
let mapleader = "\<space>"
let maplocalleader = ","
" escキーをjjに登録
inoremap <silent> jj <ESC>
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
" E21: Cannot make changes, 'modifiable' is off こんなエラー出て来た
set ma
" '%%'でアクティブなバッファのディレクトリを開いてくれる
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'
nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> [B :bfirst<CR>
nnoremap <silent> ]B :blast<CR>
" 置換の時に大活躍
set inccommand=split

" 見た目系
" 行番号を表示
set number
" 現在の行を強調表示
set cursorline
" 行末の1文字先までカーソルを移動できるように
set virtualedit=onemore
" インデントはスマートインデント
set smartindent
set noautoindent
" ビープ音を可視化
set visualbell
" 括弧入力時の対応する括弧を表示
set showmatch
set matchtime=1
" ステータスラインを常に表示
set laststatus=2
" コマンドラインの補完
set wildmenu
set wildmode=full
" 折り返し時に表示行単位での移動できるようにする
nnoremap j gj
nnoremap k gk
" 補完メニューの高さ
set pumheight=10
" 長い行があった場合
set display=lastline
" ヤンクの設定
nnoremap Y y$

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
augroup END

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
" ファイルの認識系
autocmd BufNewFile,BufRead *.jbuilder setfiletype ruby
autocmd BufNewFile,BufRead Guardfile  setfiletype ruby
autocmd BufNewFile,BufRead .pryrc     setfiletype ruby
autocmd BufNewFile,BufRead *.md       setfiletype markdown
autocmd BufNewFile,BufRead *.slim     setfiletype slim
autocmd BufNewFile,BufRead *.nim      setfiletype nim

" クリップボードにコピー
set clipboard+=unnamed

set background=dark
colorscheme apprentice

if has('nvim')
  tnoremap <silent> jj <C-\><C-n>
endif

" ファイルエクスプローラを設定
set nocompatible

" matchitを使えるように
set nocompatible
runtime macros/matchit.vim

nnoremap あ a
nnoremap い i
nnoremap う u
nnoremap お o
nnoremap っｄ dd
nnoremap っｙ yy


" pythonのホストの登録
let g:python_host_prog = '/usr/local/bin/python'
let g:python3_host_prog = '/usr/local/bin/python3'


" laravelの設定
let g:php_baselib       = 1
let g:php_htmlInStrings = 1
let g:php_noShortTags   = 1
let g:php_sql_query     = 1

let g:sql_type_default = 'mysql' " MySQLの場合
