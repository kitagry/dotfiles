set t_Co=256

set encoding=utf-8
scriptencoding utf-8

" vimrc内のautocmdを初期化
augroup vimrc
  autocmd!
augroup END

" dein config {{{
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

  call dein#add('Shougo/dein.vim')
  call dein#add('haya14busa/dein-command.vim')

  call dein#add('nvim-lua/completion-nvim')
  call dein#add('nvim-lua/diagnostic-nvim')
  call dein#add('hrsh7th/vim-vsnip')
  call dein#add('hrsh7th/vim-vsnip-integ')
  call dein#add('kitagry/vs-snippets')
  call dein#add('neovim/nvim-lspconfig')
  call dein#add('tjdevries/nlua.nvim')

  call dein#add('nvim-treesitter/nvim-treesitter', {'merged': 0})
  call dein#add('itchyny/lightline.vim')
  call dein#add('taohexxx/lightline-buffer')

  call dein#add('romainl/Apprentice')

  call dein#add('cohama/lexima.vim')
  call dein#add('machakann/vim-sandwich')
  call dein#add('tyru/caw.vim')
  call dein#add('kana/vim-repeat')
  call dein#add('kana/vim-textobj-user')
  call dein#add('sgur/vim-textobj-parameter')
  call dein#add('Julian/vim-textobj-variable-segment')
  call dein#add('lambdalisue/gina.vim', {'merged': 0})

  call dein#add('junegunn/fzf.vim')
  call dein#add('junegunn/fzf', {'on_cmd': 'fzf#install()'})
  call dein#add('lambdalisue/fern.vim')
  call dein#add('lambdalisue/nerdfont.vim')
  call dein#add('lambdalisue/fern-renderer-nerdfont.vim')

  call dein#add('kana/vim-operator-user')
  call dein#add('haya14busa/vim-operator-flashy', {
  \ 'depends': 'vim-operator-user',
  \ })

  call dein#add('hashivim/vim-terraform', {'on_ft': 'terraform'})
  call dein#add('mattn/emmet-vim')

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
  autocmd BufNewFile,BufRead *.vim  setlocal tabstop=2 softtabstop=2 shiftwidth=2
  autocmd BufNewFile,BufRead *.go   setlocal noexpandtab
augroup END


set background=dark
colorscheme apprentice
set fileformat=unix

let s:nvimrc_dir = '~/.config/nvim'
if has('win32')
    let s:nvimrc_dir = '~/AppData/Local/nvim'
endif

let s:nvimrc_local = expand(s:nvimrc_dir . '/init.local.vim')
if filereadable(s:nvimrc_local)
    execute 'source ' . s:nvimrc_local
endif

if has('win32')
  set fileformat=unix
endif

if has('mac')
  set clipboard=unnamed
endif
" }}}

" key mapping {{{
" leaderの登録
let g:mapleader = "\<space>"
nnoremap <Leader>q :set paste!<CR>

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

if has('win32') && executable('pwsh.exe')
    nnoremap <Leader>t :<C-u>:vsp term://pwsh.exe<CR>
    nnoremap <Leader>T :<C-u>:sp term://pwsh.exe<CR>
else
    nnoremap <Leader>t :<C-u>:vsp term://zsh<CR>
    nnoremap <Leader>T :<C-u>:sp term://zsh<CR>
endif

" '%%'でアクティブなバッファのディレクトリを開いてくれる
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'

inoremap <silent> <C-l> <C-G>U<Right>
inoremap <Left> <C-G>U<Left>
inoremap <Right> <C-G>U<Right>

nnoremap <Esc><Esc> :nohlsearch<CR><Esc>

autocmd FileType vim setlocal foldmethod=marker
autocmd FileType help nnoremap <buffer> q <C-w>c
autocmd FileType qf nnoremap <buffer> q :<C-u>cclose<CR>
" }}}

" completion-nvim {{{
set completeopt=menuone,noinsert,noselect
autocmd BufEnter * lua require'completion'.on_attach()
let g:completion_enable_snippet = 'vim-vsnip'
let g:completion_auto_change_source = 1
imap  <c-c> <Plug>(completion_prev_source)
imap  <c-v> <Plug>(completion_next_source)
let g:completion_chain_complete_list = {
    \   'default': [
    \      {'complete_items': ['lsp']},
    \      {'complete_items': ['snippet']},
    \      {'complete_items': ['path'], 'triggered_only': ['/']},
    \      {'mode': '<c-p>'},
    \      {'mode': '<c-n>'}
    \   ],
    \ }
" }}}

" vim-vsnip {{{
imap <expr> <C-j>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
smap <expr> <C-j>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
imap <expr> <c-k>   vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<c-k>'
smap <expr> <c-k>   vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<c-k>'
" }}}

" built in lsp {{{
lua require"lsp".setupLSP()
let g:diagnostic_enable_virtual_text = 1

function! s:reset_lsp() abort
  echomsg "restarting lsp..."
  lua vim.lsp.stop_client(vim.lsp.get_active_clients())
  sleep 100ms
  edit
endfunction
command! LspReset call s:reset_lsp()

function! s:lsp_format()
  lua require"lsp".code_action_sync("source.organizeImports")

  " This patch will be deleted when the following PR will be merged.
  " https://github.com/neovim/neovim/pull/13233
  lua require"lsp".formatting_sync()
  " lua vim.lsp.buf.formatting_sync()
endfunction

function! s:set_lsp_buffer_enabled() abort
  setlocal omnifunc=v:lua.vim.lsp.omnifunc
  nnoremap <buffer><silent><c-]>      <cmd>lua vim.lsp.buf.definition()<CR>
  nnoremap <buffer><silent><c-k>      <cmd>lua vim.lsp.buf.signature_help()<CR>
  nnoremap <buffer><silent>[e         :<C-u>PrevDiagnosticCycle<CR>
  nnoremap <buffer><silent>]e         :<C-u>NextDiagnosticCycle<CR>

  nnoremap [vim-lsp] <Nop>
  nmap     <buffer><silent><Leader>l [vim-lsp]
  nmap [vim-lsp]h <cmd>lua vim.lsp.buf.hover()<CR>
  nmap [vim-lsp]r <cmd>lua vim.lsp.buf.rename()<CR>
  nmap [vim-lsp]f <cmd>lua vim.lsp.buf.formatting()<CR>
  nmap [vim-lsp]e <cmd>lua vim.lsp.buf.references({ includeDeclaration = true })<CR>
  nmap [vim-lsp]t <cmd>lua vim.lsp.buf.type_definition()<CR>
  nmap [vim-lsp]a <cmd>lua vim.lsp.buf.code_action()<CR>
  nmap [vim-lsp]q :<C-u>LspReset<CR>

  sign define LspDiagnosticsErrorSign text=E> texthl=Error linehl= numhl=
  sign define LspDiagnosticsWarningSign text=W> texthl=WarningMsg linehl= numhl=
  sign define LspDiagnosticsInformationSign text=I> texthl=LspDiagnosticsInformation linehl= numhl=
  sign define LspDiagnosticsHintSign text=H> texthl=LspDiagnosticsHint linehl= numhl=

  augroup lsp_formatting
    au!
    autocmd BufWritePre *.go call s:lsp_format()
    autocmd BufWritePre *.rs lua require"lsp".formatting_sync()
    autocmd BufWritePre *.tsx,*ts,*.jsx,*js lua require"lsp".formatting_sync()
  augroup END
endfunction

augroup lsp_install
    au!
    autocmd BufEnter * call s:set_lsp_buffer_enabled()
augroup END
" }}}

" treesitter {{{
" ./after/lua/treesitter.lua
lua require"treesitter".setupTreesitter()
" }}}

" lightline {{{
set hidden  " allow buffer switching without saving
set showtabline=2  " always show tabline
function! LightlineLSPWarnings() abort
  let l:counts = luaeval("vim.lsp.util.buf_diagnostics_count([[Warning]])")
  return l:counts == 0 ? '' : printf('W:%d', l:counts)
endfunction

function! LightlineLSPErrors() abort
  let l:counts = luaeval("vim.lsp.util.buf_diagnostics_count([[Error]])")
  let l:result = l:counts == 0 ? '' : printf('E:%d', l:counts)
  return l:result
endfunction

function! LightlineLSPOk() abort
  let l:counts = luaeval("vim.lsp.util.buf_diagnostics_count([[Warning, Error]])")
  return l:counts == 0 ? 'OK' : ''
endfunction

augroup LightLineOnLSP
  autocmd!
  autocmd User LspDiagnosticsChanged call lightline#update()
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

" flasy.vim {{{
map y <Plug>(operator-flashy)
nmap Y <Plug>(operator-flashy)$
hi Flashy term=bold ctermbg=0 guibg=#AA354A
let g:operator#flashy#flash_time = 200
" }}}

" open-browser.vim {{{
nmap gx <Plug>(openbrowser-open)
vmap gx <Plug>(openbrowser-open)
" }}}

" gina.vim {{{
let g:gina#command#blame#formatter#format = "%su%=by %au %ma%in"
nnoremap [gina] <Nop>
vnoremap [gina] <Nop>
nmap <Leader>g [gina]
vmap <Leader>g [gina]
nmap <silent> [gina]b :<C-u>Gina blame<CR>
nmap <silent> [gina]x :Gina browse --exact :<CR>
vmap <silent> [gina]x :Gina browse --exact :<CR>

function! s:build_base_url(remote_url) abort
  for [domain, info] in items(g:gina#command#browse#translation_patterns)
    for pattern in info[0]
      let pattern = substitute(pattern, '\C' . '%domain', domain, 'g')
      if a:remote_url =~# pattern
        let repl = 'https://\1/\2/\3'
        return substitute(a:remote_url, '\C' . pattern, repl, 'g')
      endif
    endfor
  endfor
  return ''
endfunction

function! GinaOpenPr() abort
  let l:info = gina#action#candidates()
  if len(l:info) == 0
    return
  endif

  let l:info = get(l:info, 0)
  let l:commit_hash = get(l:info, 'rev')
  if l:commit_hash == 0
    return
  endif

  let l:message = system(printf("git log --oneline -n 1 --format=%%s %s", l:commit_hash))
  if len(l:message) == 0
    return
  endif
  let l:message = trim(split(l:message, '\n')[0])

  let l:match = matchstrpos(l:message, '(#\d\+)$')
  let l:pr = ''
  if l:match[1] != -1
    let l:pr = l:match[0][2:len(l:match[0])-2]
  else
    let l:message = system(printf('git log --merges --oneline --reverse --ancestry-path --format=%%s %s...master | head -n 1', l:commit_hash))
    let l:match = matchstrpos(l:message, '^Merge pull request #\d\+')
    if l:match[1] == -1
      return
    endif

    let l:pr = l:match[0][len('Merge pull request #'):]
  endif
  let l:remote_url = trim(system('git remote get-url origin'))
  let l:url = s:build_base_url(l:remote_url)
  if l:url == ''
    return
  endif
  call gina#util#open(printf('%s/pull/%s', l:url, l:pr))
endfunction

command! GinaOpenPr call GinaOpenPr()
" }}}
