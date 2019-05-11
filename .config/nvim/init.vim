set encoding=utf-8
scriptencoding utf-8

" vimrc内のautocmdを初期化
augroup vimrc
  autocmd!
augroup END

" ======================================== dein setting ========================================
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

  " 補完系
  call dein#add('prabirshrestha/async.vim')
  call dein#add('prabirshrestha/vim-lsp')
  call dein#add('prabirshrestha/asyncomplete.vim')
  call dein#add('prabirshrestha/asyncomplete-lsp.vim')
  call dein#add('prabirshrestha/asyncomplete-ultisnips.vim')
  call dein#add('honza/vim-snippets')
  call dein#add('SirVer/ultisnips')
  call dein#add('mattn/efm-langserver')

  " 移動系
  call dein#add('Shougo/neomru.vim', {'lazy': 1})
  call dein#add('Shougo/neoyank.vim', {'lazy': 1})
  call dein#add('Shougo/denite.nvim')

  call dein#add('Shougo/defx.nvim', {'lazy': 1})
  if !has('nvim')
    call dein#add('roxma/nvim-yarp')
    call dein#add('roxma/vim-hug-neovim-rpc')
  endif

  " 言語系
  call dein#add('cakebaker/scss-syntax.vim')
  call dein#add('fatih/vim-go', {'on_ft': 'go', 'lazy': 1})
  call dein#add('posva/vim-vue', {'on_ft': 'vue', 'lazy': 1})
  call dein#add('digitaltoad/vim-pug', {'on_ft': 'vue', 'lazy': 1})
  call dein#add('lervag/vimtex', {'on_ft': 'tex', 'lazy': 1})
  call dein#add('chr4/nginx.vim', {'on_ft': 'nginx', 'lazy': 1})
  call dein#add('cespare/vim-toml', {'on_ft': 'toml', 'lazy': 1})
  call dein#add('slim-template/vim-slim', {'on_ft': 'slim', 'lazy': 1})
  call dein#add('JuliaEditorSupport/julia-vim')
  call dein#add('leafgarland/typescript-vim', {'on_ft': 'typescript', 'lazy': 1})
  call dein#add('peitalin/vim-jsx-typescript', {'on_ft': 'typescript.tsx', 'lazy': 1})
  call dein#add('rust-lang/rust.vim', {'on_ft': 'rust', 'lazy': 1})

  " Git系
  call dein#add('tpope/vim-fugitive')
  call dein#add('tpope/vim-rhubarb')
  call dein#add('airblade/vim-gitgutter')

  " 見た目系
  call dein#add('romainl/Apprentice')
  call dein#add('vim-airline/vim-airline')
  call dein#add('vim-airline/vim-airline-themes')

  " コマンド拡張系
  call dein#add('cohama/lexima.vim')
  call dein#add('tpope/vim-repeat')
  call dein#add('tpope/vim-surround')
  call dein#add('tpope/vim-commentary')
  call dein#add('mattn/emmet-vim')
  call dein#add('alvan/vim-closetag')

  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
if dein#check_install()
  call dein#install()
endif
" ==============================================================================================

" ====================================== General Settings ======================================
if has('mac')
  let g:python_host_prog = '/usr/local/bin/python'
  let g:python3_host_prog = '/usr/local/bin/python3'
else
  let g:python_host_prog = '/usr/bin/python'
  let g:python3_host_prog = '/usr/bin/python3'
endif

let g:log_files_dir = $HOME . '/.config/logs'

filetype plugin indent on
syntax on

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

source $VIMRUNTIME/macros/matchit.vim

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
  autocmd BufNewFile,BufRead *.py   setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.rb   setlocal tabstop=2 softtabstop=2 shiftwidth=2
  autocmd BufNewFile,BufRead *.jl   setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.php  setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.java setlocal tabstop=4 softtabstop=4 shiftwidth=4
augroup END

" ファイルの認識系
augroup setFileType
  autocmd BufNewFile,BufRead *.nim      setfiletype nim
  autocmd BufNewFile,BufRead *.slim     setfiletype slim
  autocmd BufNewFile,BufRead *.jbuilder setfiletype ruby
  autocmd BufNewFile,BufRead Guardfile  setfiletype ruby
  autocmd BufNewFile,BufRead .pryrc     setfiletype ruby
  autocmd BufRead,BufNewFile *.scss     setfiletype sass
  autocmd BufNewFile,BufRead *.jl       setfiletype julia
  autocmd BufNewFile,BufRead *.md       setfiletype markdown
  autocmd BufNewFile,BufRead *.tsx,*jsx setfiletype typescript.tsx
  autocmd BufNewFile,BufRead *.launch   setfiletype xml
augroup end

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
nnoremap <Esc><Esc> :nohlsearch<CR><Esc>

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
" ==============================================================================================


" ======================================== Key Mapping ========================================
" leaderの登録
let g:mapleader = "\<space>"
let g:maplocalleader = ","

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

inoremap <silent> <C-l> <C-o>l
" ==============================================================================================


" =========================================== vim-lsp ==========================================
if executable('gopls')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'gopls',
        \ 'cmd': {server_info->['gopls', '-mode', 'stdio', '-logfile', g:log_files_dir . '/gopls.log']},
        \ 'whitelist': ['go'],
        \ })
endif

if executable('pyls')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'pyls',
    \ 'cmd': {server_info->['pyls']},
    \ 'whitelist': ['python'],
    \ })
endif

if executable('docker-langserver')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'docker-langserver',
    \ 'cmd': {server_info->[&shell, &shellcmdflag, 'docker-langserver --stdio']},
    \ 'whitelist': ['dockerfile'],
    \ })
endif

if executable('typescript-language-server')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'typescript-language-server',
    \ 'cmd': {server_info->[&shell, &shellcmdflag, 'typescript-language-server --stdio']},
    \ 'root_uri':{
    \   server_info->lsp#utils#path_to_uri(
    \     lsp#utils#find_nearest_parent_file_directory(
    \        lsp#utils#get_buffer_path(),
    \        'tsconfig.json')
    \ )},
    \ 'whitelist': ['typescript', 'typescript.tsx'],
    \ })
endif

if executable('julia')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'julia',
    \ 'whitelist': ['julia'],
    \ 'cmd': {server_info->['julia', '--startup-file=no', '--history-file=no', '-e', '
    \     using LanguageServer;
    \     using Pkg;
    \     import StaticLint;
    \     import SymbolServer;
    \     env_path = dirname(Pkg.Types.Context().env.project_file);
    \     debug = false;
    \
    \     server = LanguageServer.LanguageServerInstance(stdin, stdout, debug, env_path, "", Dict());
    \     server.runlinter = true;
    \     run(server);
    \ ']}
    \ })
endif

if executable('vls')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'vue',
    \ 'cmd': {server_info->['vls']},
    \ 'whitelist': ['vue'],
    \ })
endif

if executable('clangd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'clangd',
        \ 'cmd': {server_info->['clangd']},
        \ 'whitelist': ['c', 'cpp', 'objc', 'objcpp'],
        \ })
endif

if executable('solargraph')
    " gem install solargraph
    au User lsp_setup call lsp#register_server({
        \ 'name': 'solargraph',
        \ 'cmd': {server_info->[&shell, &shellcmdflag, 'solargraph stdio']},
        \ 'initialization_options': {"diagnostics": "true"},
        \ 'whitelist': ['ruby'],
        \ })
endif

if executable('rls')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'rls',
    \ 'cmd': {server_info->['rustup', 'run', 'stable', 'rls']},
    \ 'whitelist': ['rust'],
    \ })
endif

if executable('efm-langserver')
  augroup LspEFM
    au!
    autocmd User lsp_setup call lsp#register_server({
        \ 'name': 'efm-langserver',
        \ 'cmd': {server_info->['efm-langserver', '-c='.$HOME.'/.config/efm-langserver/config.yaml', '-log='.g:log_files_dir.'/efm-langserver.log']},
        \ 'whitelist': ['go'],
        \ })
  augroup END
endif

if executable('java') && filereadable(expand('~/lsp/eclipse.jdt.ls/plugins/org.eclipse.equinox.launcher_1.5.300.v20190213-1655.jar'))
    au User lsp_setup call lsp#register_server({
        \ 'name': 'eclipse.jdt.ls',
        \ 'cmd': {server_info->[
        \     'java',
        \     '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        \     '-Dosgi.bundles.defaultStartLevel=4',
        \     '-Declipse.product=org.eclipse.jdt.ls.core.product',
        \     '-Dlog.level=ALL',
        \     '-noverify',
        \     '-Dfile.encoding=UTF-8',
        \     '-Xmx1G',
        \     '-jar',
        \     expand('~/lsp/eclipse.jdt.ls/plugins/org.eclipse.equinox.launcher_1.5.300.v20190213-1655.jar'),
        \     '-configuration',
        \     expand('~/lsp/eclipse.jdt.ls/config_mac'),
        \     '-data',
        \     expand('~/lsp/eclipse.jdt.ls/workspace')
        \ ]},
        \ 'whitelist': ['java'],
        \ })
endif

let g:lsp_diagnostics_enabled = 1
let g:lsp_signs_enabled = 1
let g:lsp_diagnostics_echo_cursor = 1

nnoremap <silent> ]e  :LspNextError<CR>
nnoremap <silent> [e  :LspPreviousError<CR>
nnoremap <silent> <C-]> :LspDefinition<CR>
nnoremap <silent> <C-<> :LspTypeDefinition<CR>

nnoremap [vim-lsp] <Nop>
nmap     <Space>l [vim-lsp]

nnoremap [vim-lsp]s :LspStatus<CR>
nnoremap [vim-lsp]r :LspRename<CR>
" ==============================================================================================


" ======================================== asyncomplete ========================================
let g:lsp_log_verbose = 1
let g:lsp_log_file = expand(g:log_files_dir . '/vim-lsp.log')
let g:asyncomplete_log_file = expand(g:log_files_dir . '/asyncomplete.log')

if has('python3')
    let g:UltiSnipsExpandTrigger="<c-e>"
    call asyncomplete#register_source(asyncomplete#sources#ultisnips#get_source_options({
        \ 'name': 'ultisnips',
        \ 'whitelist': ['*'],
        \ 'completor': function('asyncomplete#sources#ultisnips#completor'),
        \ }))
endif
" ==============================================================================================


" ======================================== vim-airline ========================================
let g:airline_theme='hybrid'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
" ==============================================================================================


" =========================================== Denite ===========================================
nnoremap [denite] <Nop>
nmap     <Space>u [denite]

" カレントディレクトリ以下のファイル
nnoremap <silent> [denite]p :<C-u>Denite file_rec<CR>
" 現在のファイルのラインを検索
nnoremap <silent> [denite]l :<C-u>Denite line<CR>
" カレントディレクトリの単語検索
nnoremap <silent> [denite]g :<C-u>Denite grep -highlight-mode-insert=Search<CR>
" 検索結果（カーソル以下の文字をインプットにする）
nnoremap <silent> [denite]] :<C-u>DeniteCursorWord grep<CR>
" 最近開いたバッファ（neomru.vim依存）
nnoremap <silent> [denite]u :<C-u>Denite file_mru<CR>
" ヤンクの履歴（neoyank.vim依存）
nnoremap <silent> [denite]y :<C-u>Denite neoyank<CR>
" 前回のDeniteバッファを再表示する
nnoremap <silent> [denite]r :<C-u>Denite -resume<CR>

call denite#custom#var('file_rec', 'command', ['ag', '--follow', '--nocolor', '--nogroup', '-g'])
call denite#custom#var('grep', 'command', ['ag'])
call denite#custom#var('grep', 'recursive_opts', [])
call denite#custom#var('grep', 'pattern_opt', [])
call denite#custom#var('grep', 'default_opts', ['--follow', '--no-group', '--no-color'])
" ==============================================================================================


" ============================================ Defx ============================================
autocmd FileType defx call s:defx_my_settings()
function! s:defx_my_settings() abort
  nnoremap <silent><buffer><expr> <CR>
  \ defx#do_action('open')
  nnoremap <silent><buffer><expr> c
  \ defx#do_action('copy')
  nnoremap <silent><buffer><expr> m
  \ defx#do_action('move')
  nnoremap <silent><buffer><expr> p
  \ defx#do_action('paste')
  nnoremap <silent><buffer><expr> <C-v>
  \ defx#do_action('open', 'vsplit')
  nnoremap <silent><buffer><expr> K
  \ defx#do_action('new_directory')
  nnoremap <silent><buffer><expr> N
  \ defx#do_action('new_file')
  nnoremap <silent><buffer><expr> .
  \ defx#do_action('toggle_ignored_files')
  nnoremap <silent><buffer><expr> d
  \ defx#do_action('remove')
  nnoremap <silent><buffer><expr> r
  \ defx#do_action('rename')
  nnoremap <silent><buffer><expr> yy
  \ defx#do_action('yank_path')
  nnoremap <silent><buffer><expr> h
  \ defx#do_action('cd', ['..'])
  nnoremap <silent><buffer><expr> l
  \ defx#do_action('open')
  nnoremap <silent><buffer><expr> ~
  \ defx#do_action('cd')
  nnoremap <silent><buffer><expr> q
  \ defx#do_action('quit')
endfunction

nnoremap [defx] <Nop>
nmap <Space>d [defx]
nmap <silent> [defx]d :<C-u>Defx<CR>
nmap <silent> [defx]v :<C-u>Defx -split='vertical'<CR>
nmap <silent> [defx]f :<C-u>Defx %%<CR>
nmap <silent> [defx]h :<C-u>Defx -split='vertical' %%<CR>
" ==============================================================================================


" =================================== roxma/vim-hug-neovim-rpc =================================
let $NVIM_PYTHON_LOG_FILE=$HOME . "/.config/logs/nvim_python_log_file"
" ==============================================================================================


" =========================================== vim-go ===========================================
let g:go_fmt_command = "goimports"
let g:go_def_mapping_enabled = 0
" ==============================================================================================


" =========================================== vim-tex ===========================================
let g:vimtex_compiler_progname = 'nvr'
let g:vimtex_view_general_viewer = '/Applications/Skim.app/Contents/SharedSupport/displayline'
let g:vimtex_view_general_options = '@line @pdf @tex'
" ===============================================================================================

" =========================================== rust.vim ===========================================
let g:rustfmt_autosave = 1
" ===============================================================================================
