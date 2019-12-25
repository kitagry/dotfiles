set encoding=utf-8
scriptencoding utf-8

" vimrc内のautocmdを初期化
augroup vimrc
  autocmd!
augroup END

" dein setting {{{
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
  call dein#add('Shougo/dein.vim')
  call dein#add('prabirshrestha/async.vim')
  call dein#add('prabirshrestha/vim-lsp')
  if has('nvim')
    call dein#add('Shougo/deoplete.nvim')
    call dein#add('lighttiger2505/deoplete-vim-lsp')
    call dein#add('Shougo/neosnippet.vim')
    call dein#add('Shougo/neosnippet-snippets')
  else
    call dein#add('prabirshrestha/asyncomplete.vim')
    call dein#add('prabirshrestha/asyncomplete-buffer.vim')
    call dein#add('prabirshrestha/asyncomplete-lsp.vim')
    call dein#add('machakann/asyncomplete-ezfilter.vim')
    if has('python3')
      call dein#add('prabirshrestha/asyncomplete-ultisnips.vim')
      call dein#add('SirVer/ultisnips')
    endif
  endif

  call dein#add('honza/vim-snippets')

  " 移動系
  call dein#add('junegunn/fzf.vim')
  call dein#add('junegunn/fzf', { 'build': './install --all', 'merged': 0 })
  call dein#add('Shougo/defx.nvim', {'lazy': 1})
  if has('nvim')
    call dein#add('ncm2/float-preview.nvim')
  else
    call dein#add('roxma/nvim-yarp')
    call dein#add('roxma/vim-hug-neovim-rpc')
  endif

  " 言語系
  call dein#add('mattn/vim-goimports', {'on_ft': 'go'})
  call dein#add('lervag/vimtex', {'on_ft': 'tex', 'lazy': 1})
  call dein#add('jalvesaq/Nvim-R')
  call dein#add('sheerun/vim-polyglot')

  " Git系
  call dein#add('tpope/vim-fugitive')
  call dein#add('tpope/vim-rhubarb')
  call dein#add('airblade/vim-gitgutter')
  call dein#add('lambdalisue/gina.vim')

  " 見た目系
  call dein#add('romainl/Apprentice')
  call dein#add('gkapfham/vim-vitamin-onec')
  call dein#add('itchyny/lightline.vim')
  call dein#add('taohexxx/lightline-buffer')
  call dein#add('ryanoasis/vim-devicons')

  " コマンド拡張系
  call dein#add('cohama/lexima.vim')
  call dein#add('machakann/vim-sandwich')
  call dein#add('tpope/vim-commentary')
  call dein#add('mattn/emmet-vim')
  call dein#add('alvan/vim-closetag')
  call dein#add('thinca/vim-quickrun')
  call dein#add('vim-jp/vimdoc-ja.git')
  call dein#add('previm/previm')
  call dein#add('kana/vim-textobj-user')
  call dein#add('sgur/vim-textobj-parameter')
  call dein#add('Julian/vim-textobj-variable-segment')
  call dein#add('skywind3000/asyncrun.vim')
  call dein#add('tyru/open-browser.vim')
  call dein#add('lambdalisue/gina.vim')
  call dein#add('mattn/sonictemplate-vim')
  call dein#add('skanehira/translate.vim')

  call dein#add('kana/vim-operator-user')
  call dein#add('haya14busa/vim-operator-flashy', {
  \ 'depends': 'vim-operator-user'
  \ })

  call dein#add('vim-scripts/todo-txt.vim')

  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
if dein#check_install()
  call dein#install()
endif
" }}}

" General Settings {{{
if has('mac')
  let g:python_host_prog = '/usr/local/bin/python'
  let g:python3_host_prog = '/usr/local/bin/python3'
else
  let g:python_host_prog = '/usr/bin/python'
  let g:python3_host_prog = '/usr/bin/python3.6'
endif

let g:log_files_dir = $HOME . '/.config/logs'

filetype plugin indent on
syntax enable

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
  autocmd BufNewFile,BufRead *.html.*   setfiletype html
augroup end

" vimの折りたたみ機能を追加
au FileType vim setlocal foldmethod=marker

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
if has('mac')
    set clipboard+=unnamed
else
    set clipboard=unnamedplus
endif

set background=dark
colorscheme apprentice

" Deniteのカラーがおかしい
hi CursorLine guifg=#E19972

" vimgrepで自動でQuickfixを開く
autocmd QuickFixCmdPost *grep*,make cwindow 10

" 置換の時に大活躍
if has('nvim')
    set inccommand=split
elseif has('mac')
    " 挿入モード時に非点滅の縦棒タイプのカーソル
    let &t_SI .= "\e[6 q"
    " ノーマルモード時に非点滅のブロックタイプのカーソル
    let &t_EI .= "\e[2 q"
    " 置換モード時に非点滅の下線タイプのカーソル
    let &t_SR .= "\e[4 q"
endif

" javaを保存時にコンパイルする
autocmd BufWritePost *.java :!javac *.java

" yamlの時はvertical highlight
autocmd BufReadPost * set nocursorcolumn
autocmd BufReadPost *.yaml set cursorcolumn
" }}}

" Key Mapping {{{
" leaderの登録
let g:mapleader = "\<space>"
au FileType todo let maplocalleader = ","

" ヤンクの設定
nnoremap Y y$

" バッファ移動の設定
nnoremap ]b :bnext<CR>
nnoremap ]B :blast<CR>
nnoremap [b :bprevious<CR>
nnoremap [B :bfirst<CR>

" quickfix
nnoremap ]q :cnext<CR>
nnoremap ]Q :<C-u>clast<CR>
nnoremap [Q :<C-u>cfirst<CR>
nnoremap [q :cprevious<CR>

nnoremap ]t :tabnext<CR>
nnoremap ]T :tablast<CR>
nnoremap [t :tabprevious<CR>
nnoremap [T :tabfirst<CR>

" 折り返し時に表示行単位での移動できるようにする
nnoremap j gj
nnoremap k gk
nnoremap gj j
nnoremap gk k

" ヘルプ用
nnoremap <C-h>      :<C-u>help<Space>
nnoremap <C-h><C-h> :<C-u>help<Space><C-r><C-w><CR>

nnoremap <Leader>t :<C-u>:vertical terminal<CR>
nnoremap <Leader>T :<C-u>terminal<CR>

" '%%'でアクティブなバッファのディレクトリを開いてくれる
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'

tnoremap <silent> jj <C-\><C-n>

inoremap <silent> <C-l> <C-G>U<Right>
inoremap <Left> <C-G>U<Left>
inoremap <Right> <C-G>U<Right>

autocmd FileType help nnoremap <buffer> q <C-w>c
autocmd FileType qf nnoremap <buffer> q :<C-u>cclose<CR>

inoremap <BS> <Nop>
inoremap <Del> <Nop>
" }}}

" vim-lsp {{{
" + register lsp {{{
if executable('gopls')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'go',
        \ 'cmd': {server_info->['gopls']},
        \ 'whitelist': ['go'],
        \ 'workspace_config': {'gopls': {
        \     'usePlaceholders': v:true,
        \     'completeUnimported': v:true,
        \   }},
        \ })
endif

if executable('pyls')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'python',
    \ 'cmd': {server_info->['python3', '-m', 'pyls']},
    \ 'whitelist': ['python'],
    \ 'workspace_config': {'pyls': {'configurationSources': ['flake8']}}
    \ })
endif

if executable('docker-langserver')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'docker',
    \ 'cmd': {server_info->[&shell, &shellcmdflag, 'docker-langserver --stdio']},
    \ 'whitelist': ['dockerfile'],
    \ })
endif

if executable('typescript-language-server')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'typescript',
    \ 'cmd': {server_info->[&shell, &shellcmdflag, 'typescript-language-server --stdio']},
    \ 'root_uri':{
    \   server_info->lsp#utils#path_to_uri(
    \     lsp#utils#find_nearest_parent_file_directory(
    \        lsp#utils#get_buffer_path(),
    \        'tsconfig.json')
    \ )},
    \ 'whitelist': ['typescript', 'typescript.tsx', 'typescriptreact'],
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
        \ 'name': 'c, cpp',
        \ 'cmd': {server_info->['clangd']},
        \ 'whitelist': ['c', 'cpp', 'objc', 'objcpp'],
        \ })
endif

if executable('solargraph')
    " gem install solargraph
    au User lsp_setup call lsp#register_server({
        \ 'name': 'ruby',
        \ 'cmd': {server_info->[&shell, &shellcmdflag, 'solargraph stdio']},
        \ 'initialization_options': {"diagnostics": "true"},
        \ 'whitelist': ['ruby'],
        \ })
endif

if executable('rls')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'rust',
    \ 'cmd': {server_info->['rustup', 'run', 'stable', 'rls']},
    \ 'whitelist': ['rust'],
    \ })
endif

if executable('yaml-language-server')
  au User lsp_setup call lsp#register_server({
        \ 'name': 'yaml-language-server',
        \ 'cmd': {server_info->['yaml-language-server', '--stdio']},
        \ 'whitelist': ['yaml', 'yml'],
        \ 'workspace_config': {
        \   'yaml': {
        \     'completion': v:true,
        \     'hover': v:true,
        \     'validate': v:true,
        \     'schemas': {
        \       'Kubernetes': '/*'
        \     },
        \   },
        \   'http': {
        \     'proxyStrictSSL': v:true,
        \   },
        \ },
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
        \ 'name': 'java',
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

if executable('R')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'R',
    \ 'cmd': {server_info->['R', '--slave', '-e', 'languageserver::run()']},
    \ 'whitelist': ['R'],
    \ })
endif

" if executable('kube-langserver')
"   au User lsp_setup call lsp#register_server({
"     \ 'name': 'kube-langserver',
"     \ 'cmd': {server_info->['kube-langserver', '-log='.g:log_files_dir.'/kube-langserver.log']},
"     \ 'whitelist': ['yaml'],
"     \ })
" endif
" }}}

let g:lsp_diagnostics_enabled = 1
let g:lsp_signs_enabled = 1
let g:lsp_diagnostics_echo_cursor = 1
let g:lsp_highlights_enabled = 0
let g:lsp_preview_doubletap = 0
let g:lsp_preview_float = 1
let g:lsp_text_edit_enabled = 0

nnoremap <silent> ]e  :LspNextError<CR>
nnoremap <silent> [e  :LspPreviousError<CR>
nnoremap <silent> <C-]> :LspDefinition<CR>
nnoremap <silent> <C-<> :LspTypeDefinition<CR>

nnoremap [vim-lsp] <Nop>
nmap     <Leader>l [vim-lsp]

nnoremap [vim-lsp]v :vsp<CR>:LspDefinition<CR>
nnoremap [vim-lsp]s :LspStatus<CR>
nnoremap [vim-lsp]r :LspRename<CR>
nnoremap [vim-lsp]d :LspDocumentDiagnostics<CR>
nnoremap [vim-lsp]f :LspDocumentFormat<CR>
nnoremap [vim-lsp]h :LspHover<CR>

" stop efm-langserver
nnoremap [vim-lsp]t :call lsp#stop_server('efm-langserver')<CR>
" }}}

" asyncomplete {{{
let g:lsp_log_verbose = 1
let g:lsp_log_file = expand(g:log_files_dir . '/vim-lsp.log')
let g:asyncomplete_log_file = expand(g:log_files_dir . '/asyncomplete.log')

call asyncomplete#register_source(asyncomplete#sources#buffer#get_source_options({
    \ 'name': 'buffer',
    \ 'whitelist': ['*'],
    \ 'completor': function('asyncomplete#sources#buffer#completor'),
    \ 'config': {
    \    'max_buffer_size': 5000000,
    \  },
    \ }))

if has('python3')
    let g:UltiSnipsExpandTrigger="<c-e>"
    call asyncomplete#register_source(asyncomplete#sources#ultisnips#get_source_options({
        \ 'name': 'ultisnips',
        \ 'whitelist': ['*'],
        \ 'completor': function('asyncomplete#sources#ultisnips#completor'),
        \ }))
endif

" MEMO: fuzzyに検索するためのコード。ちょっと邪魔なので一旦無効。
" function! s:fuzzy(lhs, rhs) abort
"   return a:lhs =~ join(map(split(a:rhs, '\zs'), "printf('[\\x%02x].*', char2nr(v:val))"), '')
" endfunction

" let g:asyncomplete_preprocessor =
"   \ [function('asyncomplete#preprocessor#ezfilter#filter')]

" let g:asyncomplete#preprocessor#ezfilter#config = {}
" let g:asyncomplete#preprocessor#ezfilter#config['*'] =
"   \ {ctx, items -> filter(items, 's:fuzzy(v:val.word, ctx.base) != 0')}
" }}}

" lightline {{{
set hidden  " allow buffer switching without saving
set showtabline=2  " always show tabline
let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'fugitive#head',
      \   'bufferinfo': 'lightline#buffer#bufferinfo',
      \ },
      \ 'tabline': {
      \   'left': [ [ 'bufferinfo' ],
      \             [ 'separator' ],
      \             [ 'bufferbefore', 'buffercurrent', 'bufferafter' ], ],
      \   'right': [ [ 'close' ], ],
      \ },
      \ 'component_expand': {
      \   'buffercurrent': 'lightline#buffer#buffercurrent',
      \   'bufferbefore': 'lightline#buffer#bufferbefore',
      \   'bufferafter': 'lightline#buffer#bufferafter',
      \ },
      \ 'component_type': {
      \   'buffercurrent': 'tabsel',
      \   'bufferbefore': 'raw',
      \   'bufferafter': 'raw',
      \ },
      \ 'component': {
      \   'separator': '',
      \ },
    \ }

let g:lightline_buffer_enable_devicons = 1
" }}}

" Defx {{{
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
nmap <Leader>d [defx]
nmap <silent> [defx]d :<C-u>Defx<CR>
nmap <silent> [defx]v :<C-u>Defx -split='vertical'<CR>
nmap <silent> [defx]f :<C-u>Defx %%<CR>
nmap <silent> [defx]h :<C-u>Defx -split='vertical' %%<CR>
" }}}

" fzf {{{
"
nnoremap [fzf] <Nop>
nmap <Leader>f [fzf]
nmap <silent> [fzf]f :<C-u>Files<CR>
nmap <silent> [fzf]c :<C-u>Files %%<CR>
nmap <silent> [fzf]m :<C-u>Marks<CR>
nmap <silent> [fzf]g :<C-u>call fzf#vim#ag('', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
nmap <silent> [fzf]] :<C-u>call fzf#vim#ag('<C-r><C-w>', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
" }}}

" roxma/vim-hug-neovim-rpc {{{
let $NVIM_PYTHON_LOG_FILE=$HOME . "/.config/logs/nvim_python_log_file"
" }}}

" vim-tex {{{
let g:vimtex_compiler_progname = 'nvr'
let g:vimtex_view_general_viewer = '/Applications/Skim.app/Contents/SharedSupport/displayline'
let g:vimtex_view_general_options = '@line @pdf @tex'
" }}}

" rust.vim {{{
let g:rustfmt_autosave = 1
let g:rust_fold = 1
" }}}

" vim-quickrun {{{
" Leader + qでquickrunを閉じる
nnoremap <Leader>q :<C-u>bw! \[quickrun\ output\]<CR>

let g:quickrun_config = {}
let g:quickrun_config['tex'] = {
\ 'command' : 'latexmk',
\ 'outputter' : 'error',
\ 'outputter/error/success' : 'null',
\ 'outputter/error/error' : 'quickfix',
\ 'srcfile' : expand("%"),
\ 'cmdopt': '-pdfdvi',
\ 'hook/sweep/files' : [
\                      '%S:p:r.aux',
\                      '%S:p:r.bbl',
\                      '%S:p:r.blg',
\                      '%S:p:r.dvi',
\                      '%S:p:r.fdb_latexmk',
\                      '%S:p:r.fls',
\                      '%S:p:r.log',
\                      '%S:p:r.out'
\                      ],
\ 'exec': '%c %o %a %s',
\}
" }}}

" previm {{{
let g:previm_open_cmd = 'open -a Google\ Chrome'
let g:previm_enable_realtime = 1
let g:previm_disable_default_css = 1
let g:previm_custom_css_path = '~/.vim/templates/previm/markdown.css'
" }}}

" open-browser.vim {{{
nmap gx <Plug>(openbrowser-open)
vmap gx <Plug>(openbrowser-open)
" }}}

" calendar.vim {{{
let g:calendar_google_calendar = 1
let g:calendar_google_task = 1
" }}}

" flasy.vim {{{
map y <Plug>(operator-flashy)
nmap Y <Plug>(operator-flashy)$
hi Flashy term=bold ctermbg=0 guibg=#AA354A
let g:operator#flashy#flash_time = 200
" }}}

let s:vimrc_local = $HOME . "/.vimrc_local"
if filereadable( s:vimrc_local )
  execute "source " . s:vimrc_local
endif

function! Mdpdf() abort
  echo filereadable( expand('%:h') . '/mdpdf.css' )
  if filereadable( expand('%:h') . '/mdpdf.css' )
    execute ':AsyncRun mdpdf --style=' . expand('%:h') . '/mdpdf.css "%" && open "%<.pdf"'
  else
    execute ':AsyncRun mdpdf "%" && open "%<.pdf"'
  endif
endfunction

command! Mdpdf call Mdpdf()
