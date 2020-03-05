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
  call dein#add('haya14busa/dein-command.vim')
  call dein#add('prabirshrestha/async.vim', {'merged': 0})
  call dein#add('prabirshrestha/vim-lsp', {'merged': 0})
  call dein#add('mattn/vim-lsp-settings', {'merged': 0})
  call dein#add('prabirshrestha/asyncomplete.vim')
  call dein#add('prabirshrestha/asyncomplete-lsp.vim')
  call dein#add('hrsh7th/vim-vsnip')
  call dein#add('hrsh7th/vim-vsnip-integ')
  call dein#add('kitagry/vs-snippets')
  " call dein#local(s:dein_dir . '/repos/github.com/kitagry', {}, ['vs-snippets'])

  " 移動系
  call dein#add('junegunn/fzf.vim')
  call dein#add('junegunn/fzf', {'build': './install --all'})
  call dein#add('lambdalisue/fern.vim', {'lazy': 1})
  if has('nvim')
    call dein#add('ncm2/float-preview.nvim')
  else
    call dein#add('roxma/nvim-yarp')
    call dein#add('roxma/vim-hug-neovim-rpc')
  endif

  " 言語系
  call dein#add('mattn/vim-goimports', {'on_ft': 'go'})
  call dein#add('mattn/vim-goimpl', {'on_ft': 'go'})
  call dein#add('mattn/vim-goaddtags', {'on_ft': 'go'})
  call dein#add('kitagry/vim-gotest', {'on_ft': 'go'})
  call dein#add('lervag/vimtex', {'on_ft': 'tex'})
  call dein#add('jalvesaq/Nvim-R', {'on_ft': 'R'})
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
  \ 'depends': 'vim-operator-user'
  \ })

  call dein#add('vim-scripts/todo-txt.vim')

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

" yamlの時はvertical highlight
autocmd FileType yaml setlocal cursorcolumn
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
    \ 'whitelist': ['julia'],
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

augroup LspEFM
  au!
  autocmd User lsp_setup call lsp#register_server({
      \ 'name': 'efm-langserver',
      \ 'cmd': {server_info->['efm-langserver', '-c='.$HOME.'/.config/efm-langserver/config.yaml', '-log=' . g:log_files_dir . '/efm-langserver.log']},
      \ 'whitelist': ['go'],
      \ })
augroup END

let g:lsp_settings = {
  \   'gopls': {
  \     'workspace_config': {
  \       'gopls': {
  \         'usePlaceholders': v:true,
  \         'completeUnimported': v:true,
  \       },
  \     },
  \   },
  \   'pyls': {
  \     'cmd': ['python3', '-m', 'pyls'],
  \     'workspace_config': {'pyls': {'configurationSources': ['flake8']}},
  \   },
  \   'yaml-language-server': {
  \     'workspace_config': {
  \       'yaml': {
  \         'schemas': {
  \           'https://raw.githubusercontent.com/docker/compose/master/compose/config/config_schema_v3.4.json': '/docker-compose.yml',
  \         },
  \         'completion': v:true,
  \         'hover': v:true,
  \         'validate': v:true,
  \       },
  \     },
  \     'whitelist': ['yaml.docker-compose'],
  \   },
  \ }
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
let g:lsp_log_file = g:log_files_dir . '/vim-lsp.log'

set completeopt=menuone,noinsert,noselect
let g:lsp_signs_error = {'text': ''}
let g:lsp_signs_warning = {'text': ''}
let g:lsp_signs_hint = {'text': ''}

function! s:on_lsp_buffer_enabled() abort
  setlocal omnifunc=lsp#complete
  nmap <silent> ]e  <plug>(lsp-next-error)
  nmap <silent> [e  <plug>(lsp-previous-error)
  nmap <silent> ]w  <plug>(lsp-next-diagnostic)
  nmap <silent> [w  <plug>(lsp-previous-diagnostic)
  nmap <silent> ]r  <plug>(lsp-next-reference)
  nmap <silent> ]r  <plug>(lsp-previous-reference)
  nmap <silent> <C-]> <plug>(lsp-definition)
  nmap <silent> <C-<> <plug>(lsp-type-definition)

  nnoremap [vim-lsp] <Nop>
  nmap     <Leader>l [vim-lsp]

  nmap [vim-lsp]v :vsp<CR><plug>(lsp-definition)
  nmap [vim-lsp]s :<C-u>LspStatus<CR>
  nmap [vim-lsp]r <plug>(lsp-rename)
  nmap [vim-lsp]d <plug>(lsp-document-diagnostics)
  nmap [vim-lsp]f <plug>(lsp-document-format)
  nmap [vim-lsp]h <plug>(lsp-hover)
  nmap [vim-lsp]e <plug>(lsp-references)
  " stop efm-langserver
  nmap [vim-lsp]t :call lsp#stop_server('efm-langserver')<CR>
endfunction

augroup lsp_install
  au!
  autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END
" }}}

" vsnip {{{
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
let g:asyncomplete_auto_completeopt = 0
let g:asyncomplete_popup_delay = 200
"}}}

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

" fern {{{
nnoremap [fern] <Nop>
nmap <Leader>d [fern]
nmap <silent> [fern]d :<C-u>Fern . -opener=edit<CR>
nmap <silent> [fern]f :<C-u>Fern %:h -opener=edit<CR>
nmap <silent> [fern]v :<C-u>Fern . -opener=vsplit<CR>
nmap <silent> [fern]h :<C-u>Fern %:h -opener=vsplit<CR>
" }}}

" fzf {{{
nnoremap [fzf] <Nop>
nmap <Leader>f [fzf]
nmap <silent> [fzf]f :<C-u>Files<CR>
nmap <silent> [fzf]c :<C-u>Files %%<CR>
nmap <silent> [fzf]m :<C-u>Marks<CR>
nmap <silent> [fzf]g :<C-u>call fzf#vim#ag('', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
nmap <silent> [fzf]] :<C-u>call fzf#vim#ag('<C-r><C-w>', {'options': '--bind ctrl-a:select-all,ctrl-d:deselect-all'})<CR>
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
" }}}

" vimtex {{{
let g:latex_latexmk_options = '-pdf'
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

" polyglot {{{
let g:polyglot_disabled = ['latex']
"}}}

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

function! Todo() abort
  call popup_create(term_start(["todocli"], #{ hidden: 1, term_finish: 'close'}), #{ border: [], minwidth: winwidth(0)/2, minheight: &lines/2 })
endfunction

command! Todo call Todo()
nnoremap <Leader>kt :<C-u>Todo<CR>
