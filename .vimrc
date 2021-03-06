" windows terminal bug: https://github.com/vim-jp/issues/issues/578
if has('win32')
  " set t_u7=
  " set t_RV=
  set t_Co=256
  set t_ut=
endif

set encoding=utf-8
scriptencoding utf-8

" vimrc内のautocmdを初期化
augroup vimrc
  autocmd!
augroup END

" dein setting {{{
" プラグインが実際にインストールされるディレクトリ
let s:dein_dir_ = '~/.config/dein'
let s:dein_dir = expand(s:dein_dir_)

let s:dein_repo_dir = expand(s:dein_dir_ . '/repos/github.com/Shougo/dein.vim')

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif

  execute 'set runtimepath^=' . s:dein_repo_dir
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " 補完系
  call dein#add('Shougo/dein.vim')
  call dein#add('haya14busa/dein-command.vim')
  call dein#add('prabirshrestha/vim-lsp')
  call dein#add('mattn/vim-lsp-settings')
  call dein#add('prabirshrestha/asyncomplete.vim', {'merged': 0})
  call dein#add('prabirshrestha/asyncomplete-lsp.vim', {'merged': 0})
  call dein#add('prabirshrestha/asyncomplete-buffer.vim')
  call dein#add('hrsh7th/vim-vsnip')
  call dein#add('hrsh7th/vim-vsnip-integ')
  call dein#add('kitagry/vs-snippets')
  call dein#add('kitagry/vim-gotest')
  call dein#add('kitagry/asyncomplete-tabnine.vim')
  " call dein#add('mattn/asyncomplete-skk.vim', {'merged': 0})
  call dein#add('prabirshrestha/async.vim')

  " 移動系
  call dein#add('ctrlpvim/ctrlp.vim')
  call dein#add('mattn/ctrlp-lsp')
  call dein#add('kitagry/ctrlp-goimpl')
  call dein#add('junegunn/fzf.vim')
  call dein#add('junegunn/fzf', {'on_cmd': 'fzf#install()'})
  call dein#add('lambdalisue/fern.vim', {'merged': 0})
  call dein#add('lambdalisue/nerdfont.vim')
  call dein#add('lambdalisue/fern-renderer-nerdfont.vim')

  " 言語系
  call dein#add('mattn/vim-goimpl', {'on_ft': 'go'})
  call dein#add('mattn/vim-goaddtags', {'on_ft': 'go'})
  call dein#add('lervag/vimtex', {'on_ft': 'tex'})
  call dein#add('jalvesaq/Nvim-R', {'on_ft': 'R'})
  call dein#add('pprovost/vim-ps1', {'on_ft': 'powershell'})
  call dein#add('rust-lang/rust.vim', {'on_ft': 'rust'})
  call dein#add('hashivim/vim-terraform')

  " Git系
  call dein#add('airblade/vim-gitgutter')

  " 見た目系
  call dein#add('romainl/Apprentice', {'merged': 0})
  call dein#add('itchyny/lightline.vim')
  call dein#add('taohexxx/lightline-buffer')

  " コマンド拡張系
  call dein#add('cohama/lexima.vim')
  call dein#add('machakann/vim-sandwich')
  call dein#add('tyru/caw.vim')
  call dein#add('kana/vim-repeat')
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
  \ 'depends': 'vim-operator-user',
  \ })

  call dein#add('vim-scripts/todo-txt.vim')
  call dein#add('godlygeek/tabular')
  call dein#add('plasticboy/vim-markdown')
  call dein#add('Shougo/context_filetype.vim')
  call dein#add('delphinus/vim-firestore')

  " テスト用
  call dein#add('thinca/vim-themis')
  call dein#add('mattn/vim-go2')
  call dein#add('mattn/webapi-vim')
  call dein#add('tsandall/vim-rego')

  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
augroup PluginInstall
  autocmd!
  autocmd VimEnter * if dein#check_install() | call dein#install() | endif
augroup END
" }}}

" General Settings {{{
if filereadable('/usr/local/opt/python@3/bin/python3')
  let g:python3_host_prog = '/usr/local/opt/python@3/bin/python3'
elseif filereadable('/usr/local/bin/python3')
  let g:python3_host_prog = '/usr/local/bin/python3'
elseif filereadable('/usr/bin/python3')
  let g:python3_host_prog = '/usr/bin/python3'
endif

if filereadable('/usr/local/bin/python')
  let g:python_host_prog = '/usr/local/bin/python'
elseif filereadable('/usr/bin/python')
  let g:python_host_prog = '/usr/bin/python'
endif

if !isdirectory($HOME . '/Library/Logs/vim')
  silent !mkdir -p "$HOME/Library/Logs/vim"
endif
let g:log_files_dir = $HOME . '/Library/Logs/vim'

filetype plugin indent on
syntax enable

" バックアップファイルを作らない
set nobackup
" スワップファイルを作らない
set noswapfile
" undoファイルを作らない
set noundofile
" 編集中のファイルが変更されたら自動で読み直す
set autoread
" バッファが編集中でもその他のファイルを開けるように
set hidden
" 入力中のコマンドをステータスに表示する
set showcmd
" 保存時に余計なスペースを削除
autocmd BufWritePre * call s:remove_unnecessary_space()

function! s:remove_unnecessary_space()
    " delete last spaces
    %s/\s\+$//ge

    " delete last blank lines
    while getline('$') == "" && len(join(getline(0, '$')))
            $delete _
    endwhile
endfunction

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
  autocmd BufNewFile,BufRead *.jl   setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.php  setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.java setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.vim  setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.go   setlocal noexpandtab
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
augroup END

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
elseif has('unix')
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
endif

if &term =~ '^xterm'
    " 挿入モード時に非点滅の縦棒タイプのカーソル
    let &t_SI .= "\e[6 q"
    " ノーマルモード時に非点滅のブロックタイプのカーソル
    let &t_EI .= "\e[2 q"
    " 置換モード時に非点滅の下線タイプのカーソル
    let &t_SR .= "\e[4 q"
elseif &term == 'win32'
    " let &t_ti .= " \e[1 q"
    " let &t_SI .= " \e[5 q"
    " let &t_EI .= " \e[1 q"
    " let &t_te .= " \e[0 q"
endif

" yamlの時はvertical highlight
autocmd FileType yaml setlocal cursorcolumn
autocmd FileType yaml lcd %:h

if has('win32')
  set fileformat=unix
endif
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
vnoremap j gj
vnoremap k gk
vnoremap gj j
vnoremap gk k
nnoremap j gj
nnoremap k gk
nnoremap gj j
nnoremap gk k

" ヘルプ用
set helplang=ja,en

if has('win32')
  nnoremap <Leader>t :<C-u>:vertical terminal pwsh<CR>
  nnoremap <Leader>T :<C-u>terminal pwsh<CR>
else
  nnoremap <Leader>t :<C-u>:vertical terminal<CR>
  nnoremap <Leader>T :<C-u>terminal<CR>
endif

" '%%'でアクティブなバッファのディレクトリを開いてくれる
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'

inoremap <silent> <C-l> <C-G>U<Right>
inoremap <Left> <C-G>U<Left>
inoremap <Right> <C-G>U<Right>

autocmd FileType help nnoremap <buffer> q <C-w>c
autocmd FileType qf nnoremap <buffer> q :<C-u>cclose<CR>

inoremap <BS> <Nop>
inoremap <Del> <Nop>
" }}}

" vim-lsp-settings {{{
if executable('julia')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'julia',
    \ 'allowlist': ['julia'],
    \ 'cmd': {server_info->['julia', '--startup-file=no', '--history-file=no', '-e', '
    \       using LanguageServer;
    \       using Pkg;
    \       import StaticLint;
    \       import SymbolServer;
    \       env_path = dirname(Pkg.Types.Context().env.project_file);
    \       debug = false;
    \
    \       server = LanguageServer.LanguageServerInstance(stdin, stdout, debug, env_path, "", Dict());
    \       server.runlinter = true;
    \       run(server);
    \ ']}
    \ })
endif

if executable('ocamllsp')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'julia',
    \ 'allowlist': ['ocaml'],
    \ 'cmd': {server_info->['ocamllsp']}
    \ })
endif

" if executable('yamls')
"   au User lsp_setup call lsp#register_server({
"    \   'name': 'yamls',
"    \   'allowlist': ['yaml'],
"    \   'cmd': {server_info->['yamls']}
"    \ })
" endif

augroup LspEFM
  au!
  autocmd User lsp_setup call lsp#register_server({
      \ 'name': 'efm-langserver',
      \ 'cmd': {server_info->['efm-langserver', '-c=' . expand($APPDATA . '/efm-langserver/config.yaml'), '-logfile=' . expand(g:log_files_dir . '/efm-langserver.log')]},
      \ 'allowlist': ['go', 'python', 'vim', 'markdown', 'tex'],
      \ })
augroup END

let g:lsp_settings = {
  \   'gopls': {
  \     'initialization_options': {
  \       'usePlaceholders': v:true,
  \       'gofumpt': v:true,
  \       'staticcheck': v:true,
  \       'analyses': {
  \         'fillstruct': v:true,
  \       },
  \       'codelens': {
  \         'vendor': v:true,
  \         'tidy': v:true,
  \         'test': v:true,
  \       },
  \     },
  \   },
  \   'yaml-language-server': {
  \     'workspace_config': {
  \       'yaml': {
  \         'schemas': {
  \           'https://raw.githubusercontent.com/docker/compose/master/compose/config/config_schema_v3.4.json': '/docker-compose.yml',
  \           'kubernetes': '/deployment.yaml',
  \         },
  \         'completion': v:true,
  \         'hover': v:true,
  \         'validate': v:true,
  \       },
  \     },
  \     'allowlist': ['yaml.docker-compose', 'yaml'],
  \   },
  \   'golangci-lint-langserver': {
  \     'cmd': ['golangci-lint-langserver', '-debug'],
  \   },
  \ }
let g:lsp_settings_filetype_go = ['gopls', 'golangci-lint-langserver', 'efm-langserver']
" }}}

" vim-lsp {{{
let g:lsp_diagnostics_enabled = 1
let g:lsp_signs_enabled = 1
let g:lsp_diagnostics_echo_cursor = 1
let g:lsp_highlights_enabled = 0
let g:lsp_preview_float = 1
let g:lsp_text_edit_enabled = 0
let g:lsp_async_completion = 1
let g:lsp_diagnostics_float_cursor = 1
let g:lsp_log_verbose = 1
let g:lsp_log_file = expand(g:log_files_dir . '/vim-lsp.log')

let g:lsp_signs_error = {'text': ''}
let g:lsp_signs_warning = {'text': ''}
let g:lsp_signs_hint = {'text': ''}

autocmd BufWritePre *.go call execute(['LspCodeActionSync source.organizeImports', 'LspDocumentFormatSync'])

function! s:on_lsp_buffer_enabled() abort
  setlocal omnifunc=lsp#complete
  nmap <silent> ]e  <plug>(lsp-next-error)
  nmap <silent> [e  <plug>(lsp-previous-error)
  nmap <silent> ]w  <plug>(lsp-next-diagnostic)
  nmap <silent> [w  <plug>(lsp-previous-diagnostic)
  nmap <silent> ]e  <plug>(lsp-next-reference)
  nmap <silent> ]e  <plug>(lsp-previous-reference)
  nmap <silent> <C-]> <plug>(lsp-definition)

  nnoremap [vim-lsp] <Nop>
  nmap     <Leader>l [vim-lsp]

  nmap [vim-lsp]v :vsp<CR><plug>(lsp-definition)
  nmap [vim-lsp]s :<C-u>LspStatus<CR>
  nmap [vim-lsp]r <plug>(lsp-rename)
  nmap [vim-lsp]d <plug>(lsp-document-diagnostics)
  nmap [vim-lsp]f <plug>(lsp-document-format)
  nmap [vim-lsp]h <plug>(lsp-hover)
  nmap [vim-lsp]e <plug>(lsp-references)
  nmap [vim-lsp]t <plug>(lsp-type-definition)

  " stop efm-langserver
  " nmap [vim-lsp]t :call lsp#stop_server('efm-langserver')<CR>
endfunction

augroup lsp_install
  au!
  autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END
" }}}

" vsnip {{{
let g:vsnip_snippet_dir = expand('~/.vim/vsnip')
let g:vsnip_snippet_dirs = split(globpath(&runtimepath, 'snippets'), '\n')
imap <expr> <C-e>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-e>'
smap <expr> <C-e>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-e>'
imap <expr> <C-j>   vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
smap <expr> <C-j>   vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
imap <expr> <C-k> vsnip#available(-1)   ? '<Plug>(vsnip-jump-prev)'      : '<C-k>'
smap <expr> <C-k> vsnip#available(-1)   ? '<Plug>(vsnip-jump-prev)'      : '<C-k>'
" }}}

" asyncomplete {{{
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_popup_delay = 200
let g:asyncomplete_log_file = g:log_files_dir . '/asyncomplete.log'
" imap <c-\> <plug>(asyncomplete-skk-toggle)
" call asyncomplete#register_source(asyncomplete#sources#tabnine#get_source_options({
"\ 'name': 'tabnine',
"\ 'allowlist': ['*'],
"\ 'completor': function('asyncomplete#sources#tabnine#completor'),
"\ }))
"}}}

" sonictemplate {{{
let g:sonictemplate_vim_template_dir = expand('~/.vim/sonictemplate')
"}}}

" lightline {{{
set hidden  " allow buffer switching without saving
set showtabline=2  " always show tabline
function! LightlineLSPWarnings() abort
  let l:counts = lsp#ui#vim#diagnostics#get_buffer_diagnostics_counts()
  return l:counts.warning == 0 ? '' : printf('W:%d', l:counts.warning)
endfunction

function! LightlineLSPErrors() abort
  let l:counts = lsp#ui#vim#diagnostics#get_buffer_diagnostics_counts()
  return l:counts.error == 0 ? '' : printf('E:%d', l:counts.error)
endfunction

function! LightlineLSPOk() abort
  let l:counts =  lsp#ui#vim#diagnostics#get_buffer_diagnostics_counts()
  let l:total = l:counts.error + l:counts.warning
  return l:total == 0 ? 'OK' : ''
endfunction

augroup LightLineOnLSP
  autocmd!
  autocmd User lsp_diagnostics_updated call lightline#update()
augroup END

let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'active': {
      \   'left': [
      \     [ 'mode', 'paste' ],
      \   ],
      \   'right': [
      \     [ 'lsp_errors', 'lsp_warnings', 'lsp_ok' ],
      \     [ 'percent' ],
      \     [ 'fileformat', 'fileencoding', 'filetype'  ],
      \   ],
      \ },
      \ 'component_function': {
      \   'bufferinfo': 'lightline#buffer#bufferinfo',
      \ },
      \ 'tabline': {
      \   'left': [ [ 'bufferbefore', 'buffercurrent', 'bufferafter' ]],
      \   'right': [ [ 'close' ], ],
      \ },
      \ 'component_expand': {
      \   'buffercurrent': 'lightline#buffer#buffercurrent',
      \   'bufferbefore': 'lightline#buffer#bufferbefore',
      \   'bufferafter': 'lightline#buffer#bufferafter',
      \   'lsp_warnings': 'LightlineLSPWarnings',
      \   'lsp_errors':   'LightlineLSPErrors',
      \   'lsp_ok':       'LightlineLSPOk',
      \ },
      \ 'component_type': {
      \   'buffercurrent': 'tabsel',
      \   'bufferbefore': 'raw',
      \   'bufferafter': 'raw',
      \   'lsp_warnings': 'warning',
      \   'lsp_errors':   'error',
      \   'lsp_ok':       'middle',
      \ },
      \ 'component': {
      \   'separator': '',
      \ },
    \ }
" }}}

" fern {{{
nnoremap [fern] <Nop>
nmap <Leader>d [fern]
nmap <silent> [fern]a :<C-u>Fern . -drawer -toggle -reveal=%<CR>
nmap <silent> [fern]r :<C-u>FernDo :<CR>
nmap <silent> [fern]d :<C-u>Fern . -opener=edit<CR>
nmap <silent> [fern]f :<C-u>Fern %:h -opener=edit<CR>
nmap <silent> [fern]v :<C-u>Fern . -opener=vsplit<CR>
nmap <silent> [fern]h :<C-u>Fern %:h -opener=vsplit<CR>
let g:fern#renderer = "nerdfont"
" }}}

" fzf {{{
nnoremap [fzf] <Nop>
nmap <Leader>f [fzf]
nmap <silent> [fzf]f :<C-u>Files<CR>
nmap <silent> [fzf]c :<C-u>Files %%<CR>
nmap <silent> [fzf]m :<C-u>Marks<CR>
nmap <silent> [fzf]g :<C-u>call fzf#vim#ag('', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
nmap <silent> [fzf]] :<C-u>call fzf#vim#ag('<C-r><C-w>', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
" }}}

" vimtex {{{
let g:tex_flavor = 'latex'
if has('osxdarwin')
  let g:latex_latexmk_options = '-pdf'
  let g:vimtex_view_general_viewer = '/Applications/Skim.app/Contents/SharedSupport/displayline'
  let g:vimtex_view_general_options = '@line @pdf @tex'
elseif has('win32')
  let g:vimtex_compiler_latexmk = {
    \ 'build_dir': '',
    \ 'callback': 1,
    \ 'continuous': 1,
    \ 'executable': 'latexmk',
    \ 'hooks': [],
    \ 'options': [
    \   '-pdfxe'
    \ ],
    \}
  " let g:latex_latexmk_options = '-pdfxe'
  let g:vimtex_view_general_viewer = 'AcroRd32.exe'
endif
let g:vimtex_view_general_options_latexmk = ''
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

" setting-go {{{
augroup goshortcut
  autocmd!
  nnoremap [go] <Nop>
  nmap <Leader>g [go]

  nnoremap [go]t :GoTest -short<CR>
  nnoremap [go]i :GoImport
  nnoremap [go]p :GoImpl
augroup end
"}}}

" gina.vim {{{
let g:gina#command#blame#formatter#format = "%su%=by %au %ma%in"
" call gina#custom#mapping#nmap(
"      \ 'blame', 'j',
"      \ 'j<Plug>(gina-blame-echo)'
"      \)
" call gina#custom#mapping#nmap(
"      \ 'blame', 'k',
"      \ 'k<Plug>(gina-blame-echo)'
"      \)
" }}}

" context_filetype {{{
" let g:context_filetype#filetypes = {
"      \ 'markdown': [
"      \   {
"      \     'start': '^\s*```\s*\(\h\w*\):[a-zA-Z_./]*',
"      \     'end':  '^\s*```$',
"      \     'filetype': '\1',
"      \   }
"      \ ]}
" }}}

let s:vimrc_local = $HOME . "/.vimrc.local"
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

function! Todo() abort
  call popup_create(term_start(["todocli"], #{ hidden: 1, term_finish: 'close'}), #{ border: [], minwidth: winwidth(0)/2, minheight: &lines/2 })
endfunction

command! Todo call Todo()
nnoremap <Leader>kt :<C-u>Todo<CR>
let g:vim_markdown_folding_disabled = 1

function! GinaOpenPr() abort
  redir => s:messages
    call gina#action#call('blame:echo')
  redir END
  let s:lastmsg = get(split(s:messages, "\n"), -1, "")
  let s:commit_hash = matchstr(s:lastmsg, '\[.*\]$')
  if strlen(s:commit_hash) < 2
    return
  endif

  let s:commit_hash = s:commit_hash[1:strlen(s:commit_hash)-2]
  call system(printf("git openpr %s", s:commit_hash))
endfunction

command! GinaOpenPr call GinaOpenPr()
