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

  call dein#add('hrsh7th/nvim-cmp')
  call dein#add('hrsh7th/cmp-buffer')
  call dein#add('hrsh7th/cmp-vsnip')
  call dein#add('hrsh7th/cmp-nvim-lua')
  call dein#add('hrsh7th/cmp-nvim-lsp')
  call dein#add('hrsh7th/cmp-cmdline')
  call dein#add('hrsh7th/cmp-path')
  call dein#add('hrsh7th/vim-vsnip')
  call dein#add('hrsh7th/vim-vsnip-integ')
  call dein#add('kitagry/vs-snippets', {'merged': 0})
  call dein#add('neovim/nvim-lspconfig', {'merged': 0})
  call dein#add('nvim-lua/lsp_extensions.nvim')
  call dein#add('nvim-lua/popup.nvim')
  call dein#add('nvim-lua/plenary.nvim')
  call dein#add('nvim-telescope/telescope.nvim')
  call dein#add('nvim-telescope/telescope-github.nvim')
  call dein#add('nvim-telescope/telescope-ghq.nvim')

  call dein#add('nvim-treesitter/nvim-treesitter', {'merged': 0})
  call dein#add('itchyny/lightline.vim')
  call dein#add('taohexxx/lightline-buffer')

  call dein#add('romainl/Apprentice')

  call dein#add('machakann/vim-sandwich')
  call dein#add('tyru/caw.vim')
  call dein#add('tyru/open-browser.vim')
  call dein#add('kana/vim-repeat')
  call dein#add('kana/vim-textobj-user')
  call dein#add('sgur/vim-textobj-parameter')
  call dein#add('Julian/vim-textobj-variable-segment')
  call dein#add('lambdalisue/gina.vim', {'merged': 0})
  call dein#add('kitagry/gina-openpr.vim', {'merged': 0})
  call dein#local(expand(s:dein_dir_ . '/repos/github.com/kitagry'), {}, ['nvim-treesitter-goaddtags', 'dpsh-vim'])

  call dein#add('lambdalisue/fern.vim')
  call dein#add('lambdalisue/nerdfont.vim')
  call dein#add('lambdalisue/fern-renderer-nerdfont.vim')
  call dein#add('lambdalisue/fern-hijack.vim')
  call dein#add('mattn/vim-goaddtags', {'merged': 0})
  call dein#add('mattn/vim-goimpl')

  call dein#add('kana/vim-operator-user')
  call dein#add('haya14busa/vim-operator-flashy', {
  \ 'depends': 'vim-operator-user',
  \ })

  call dein#add('hashivim/vim-terraform', {'on_ft': 'terraform'})
  call dein#add('mattn/emmet-vim')
  call dein#add('rhysd/rust-doc.vim')
  call dein#add('sainnhe/sonokai')
  call dein#add('segeljakt/vim-silicon')
  call dein#add('windwp/nvim-autopairs')
  call dein#add('lambdalisue/suda.vim')
  call dein#add('vim-denops/denops.vim')
  call dein#add('lambdalisue/pastefix.vim')
  call dein#add('tversteeg/registers.nvim')
  call dein#add('norcalli/nvim-colorizer.lua')
  call dein#add('lambdalisue/reword.vim')
  call dein#add('tokorom/vim-review')
  call dein#add('kabouzeid/nvim-lspinstall')
  call dein#add('simrat39/rust-tools.nvim')
  call dein#add('thinca/vim-quickrun')
  call dein#add('oky-123/marksign.vim', {'merged': 0})
  call dein#add('monaqa/dial.nvim')
  call dein#add('yuki-yano/fuzzy-motion.vim')

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

set ignorecase
set inccommand=split

augroup fileTypeIndent
  autocmd!
  autocmd BufNewFile,BufRead *.py   setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.jl   setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.php  setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.java setlocal tabstop=4 softtabstop=4 shiftwidth=4
  autocmd BufNewFile,BufRead *.vim  setlocal tabstop=2 softtabstop=2 shiftwidth=2
  autocmd BufNewFile,BufRead *.go   setlocal noexpandtab
  autocmd BufNewFile,BufRead *.rego   setlocal noexpandtab
augroup END

augroup setFileType
  autocmd!
  autocmd BufNewFile,BufRead *.nim      setfiletype nim
  autocmd BufNewFile,BufRead *.slim     setfiletype slim
  autocmd BufNewFile,BufRead *.jbuilder setfiletype ruby
  autocmd BufNewFile,BufRead Guardfile  setfiletype ruby
  autocmd BufNewFile,BufRead .pryrc     setfiletype ruby
  autocmd BufRead,BufNewFile *.scss     setfiletype sass
  autocmd BufNewFile,BufRead *.jl       setfiletype julia
  autocmd BufNewFile,BufRead *.md       setfiletype markdown
  autocmd BufNewFile,BufRead *.launch   setfiletype xml
  autocmd BufNewFile,BufRead *.html.*   setfiletype html
augroup END

set background=dark
let g:sonokai_style = 'shusia'
set termguicolors
colorscheme sonokai

let s:nvimrc_dir = '~/.config/nvim'
if has('win32')
    let s:nvimrc_dir = '~/AppData/Local/nvim'
endif

let s:nvimrc_local = expand(s:nvimrc_dir . '/init.local.vim')
if filereadable(s:nvimrc_local)
    execute('source ' . s:nvimrc_local)
endif

set cursorline

augroup setCursorColumn
  autocmd!
  autocmd BufNewFile,BufRead *.yaml setlocal cursorcolumn
augroup END

if has('win32')
  set termguicolors
  augroup vim_setfiletype
    autocmd!
    autocmd BufNewFile * set fileformat=unix
  augroup END
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

function s:specific_keymap_init() abort
  " 言語特有のkeymapping
  nnoremap [special_lang] <Nop>
  nmap     <buffer><silent><Leader>h [special_lang]
endfunction

function s:golang_set() abort
  call s:specific_keymap_init()
  nmap <buffer> [special_lang]t <cmd>lua require("kitagry.go").toggle_test_file()<CR>
endfunction

augroup lang_specific_settings
  au!
  autocmd FileType go call s:golang_set()
augroup END
" }}}

" nvim-cmp {{{
set completeopt=menuone,noinsert,noselect
lua <<EOF
  local cmp = require('cmp')
  local get_bufnrs = function()
    local bufs = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      bufs[vim.api.nvim_win_get_buf(win)] = true
    end
    return vim.tbl_keys(bufs)
  end
  cmp.setup {
    snippet = {
      expand = function(args)
        vim.fn['vsnip#anonymous'](args.body)
      end
    },

    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({
        select = false,
      })
    },

    sources = {
      { name = 'nvim_lsp' },
      { name = 'vsnip' },
      {
        name = 'buffer',
        option = {
          get_bufnrs = get_bufnrs
        }
      },
    },

    formatting = {
      format = function(entry, vim_item)
        vim_item.menu = ({
          nvim_lsp = '[LSP]',
          vsnip = '[vsnip]',
          cmdline = '[cmdline]',
          path = '[path]',
          buffer = '[Buffer]',
        })[entry.source.name]
        return vim_item
      end
    },
    preselect = cmp.PreselectMode.None,
  }

  cmp.setup.cmdline(':', {
    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
    },
    sources = {
      { name = 'cmdline' },
      { name = 'path' },
    }
  })

  cmp.setup.cmdline('/', {
    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
    },
    sources = {
      { name = 'buffer' }
    }
  })

  _G.vimrc = _G.vimrc or {}
  _G.vimrc.cmp = _G.vimrc.cmp or {}
  _G.vimrc.cmp.lsp = function()
    cmp.complete({
      config = {
        sources = {
          { name = 'nvim_lsp' }
        }
      }
    })
  end

  vim.cmd([[
    inoremap <C-x><C-o> <Cmd>lua vimrc.cmp.lsp()<CR>
  ]])
EOF

autocmd FileType lua lua require'cmp'.setup.buffer {
\   sources = {
\     { name = 'buffer' },
\     { name = 'nvim_lua' },
\   },
\ }
" }}}

" vim-vsnip {{{
imap <expr> <C-j>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
smap <expr> <C-j>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<C-j>'
imap <expr> <c-k>   vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<c-k>'
smap <expr> <c-k>   vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<c-k>'
let g:vsnip_snippet_dir="~/.vim/vsnip/"
" }}}

" built in lsp {{{
lua require"kitagry.lsp".setupLSP()
" lua vim.lsp.set_log_level(0)

function! s:reset_lsp() abort
  echomsg "restarting lsp..."
  lua vim.lsp.stop_client(vim.lsp.get_active_clients())
  sleep 100ms
  edit
endfunction
command! LspReset call s:reset_lsp()

function! s:lsp_format()
  lua require"kitagry.lsp".code_action_sync("source.organizeImports")
  lua vim.lsp.buf.formatting_sync()
endfunction

function! s:set_lsp_buffer_enabled() abort
  setlocal omnifunc=v:lua.vim.lsp.omnifunc
  nnoremap <buffer><silent><c-]>      <cmd>lua vim.lsp.buf.definition()<CR>
  nnoremap <buffer><silent><c-k>      <cmd>lua vim.lsp.buf.signature_help()<CR>
  nnoremap <buffer><silent>[e         <cmd>lua vim.lsp.diagnostic.goto_prev()<CR>
  nnoremap <buffer><silent>]e         <cmd>lua vim.lsp.diagnostic.goto_next()<CR>

  nnoremap [vim-lsp] <Nop>
  nmap     <buffer><silent><Leader>l [vim-lsp]
  nmap [vim-lsp]h <cmd>lua vim.lsp.buf.hover()<CR>
  nmap [vim-lsp]r <cmd>lua vim.lsp.buf.rename()<CR>
  nmap [vim-lsp]f <cmd>lua vim.lsp.buf.formatting()<CR>
  nmap [vim-lsp]e <cmd>lua vim.lsp.buf.references({ includeDeclaration = true })<CR>
  nmap [vim-lsp]t <cmd>lua vim.lsp.buf.type_definition()<CR>
  nmap [vim-lsp]a <cmd>lua vim.lsp.buf.code_action()<CR>
  nmap [vim-lsp]q :<C-u>LspReset<CR>
  nmap [vim-lsp]s :<C-u>LspInfo<CR>
  nmap [vim-lsp]a <cmd>lua require'telescope.builtin'.lsp_code_actions()<CR>

  sign define LspDiagnosticsErrorSign text=E> texthl=Error linehl= numhl=
  sign define LspDiagnosticsWarningSign text=W> texthl=WarningMsg linehl= numhl=
  sign define LspDiagnosticsInformationSign text=I> texthl=LspDiagnosticsInformation linehl= numhl=
  sign define LspDiagnosticsHintSign text=H> texthl=LspDiagnosticsHint linehl= numhl=

  augroup lsp_formatting
    au!
    autocmd BufWritePre *.go call s:lsp_format()
    autocmd BufWritePre *.rs call s:lsp_format()
    autocmd BufWritePre *.tsx,*ts,*.jsx,*js lua vim.lsp.buf.formatting_sync()
    autocmd BufWritePre *.py lua vim.lsp.buf.formatting_sync({}, 300)
    autocmd BufWritePre *.rego lua vim.lsp.buf.formatting_sync()
  augroup END
endfunction

" function s:set_typescript_shortcut() abort
"   " nnoremap <buffer><silent><c-]>      <cmd>lua require('lspconfig').denols.definition()<CR>
"
"   nmap [vim-lsp]e <cmd>lua require('lspconfig').denols.references({ includeDeclaration = true })<CR>
" endfunction

augroup lsp_install
    au!
    autocmd BufEnter * call s:set_lsp_buffer_enabled()
    " autocmd BufEnter *.ts,*.tsx call s:set_typescript_shortcut()
augroup END
" }}}

" treesitter {{{
" ./after/lua/treesitter.lua
lua require"kitagry.treesitter".setupTreesitter()
" }}}

" lightline {{{
set hidden  " allow buffer switching without saving
set showtabline=2  " always show tabline
function! LightlineLSPWarnings() abort
  let l:counts = luaeval("#vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })")
  return l:counts == 0 ? '' : printf('W:%d', l:counts)
endfunction

function! LightlineLSPErrors() abort
  let l:counts = luaeval("#vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })")
  let l:result = l:counts == 0 ? '' : printf('E:%d', l:counts)
  return l:result
endfunction

function! LightlineLSPOk() abort
  let l:counts = luaeval("#vim.diagnostic.get(0, { severity = { min = vim.diagnostic.severity.WARN }})")
  return l:counts == 0 ? 'OK' : ''
endfunction

augroup LightLineOnLSP
  autocmd!
  autocmd User LspDiagnosticsChanged call lightline#update()
augroup END

let g:lightline = {
      \ 'colorscheme': 'sonokai',
      \ 'active': {
      \   'left': [
      \     [ 'mode', 'paste' ],
      \     [ 'current_branch' ],
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
      \ },
      \ 'component_expand': {
      \   'current_branch': 'gina#component#repo#branch',
      \   'buffercurrent': 'lightline#buffer#buffercurrent',
      \   'bufferbefore': 'lightline#buffer#bufferbefore',
      \   'bufferafter': 'lightline#buffer#bufferafter',
      \   'lsp_warnings': 'LightlineLSPWarnings',
      \   'lsp_errors':   'LightlineLSPErrors',
      \   'lsp_ok':       'LightlineLSPOk',
      \ },
      \ 'component_type': {
      \   'current_branch': 'middle',
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

function! s:init_fern() abort
  nmap <buffer> R <Plug>(fern-action-remove)
  nmap <buffer> r <Plug>(fern-action-rename)
endfunction

augroup my-fern
  autocmd!
  autocmd FileType fern call s:init_fern()
augroup END
" }}}

" telescope {{{
lua require("kitagry.telescope")
nnoremap [telescope] <Nop>
nmap <Leader>f [telescope]
nmap <silent> [telescope]r <cmd>lua require('telescope.builtin').resume(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]f <cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]g <cmd>lua require('telescope.builtin').live_grep(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]] <cmd>lua require('telescope.builtin').grep_string(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]d <cmd>lua require('telescope.builtin').lsp_document_symbols(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]b <cmd>lua require('telescope.builtin').buffers(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]t <cmd>lua require('telescope.builtin').filetypes(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]h <cmd>lua require('telescope.builtin').help_tags(require('telescope.themes').get_ivy())<CR>
nmap <silent> [telescope]a <cmd>lua require('telescope.builtin').git_branches(require('telescope.themes').get_ivy())<CR>
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
set diffopt=vertical
let g:gina#command#blame#formatter#format = "%su%=by %au %ma%in"
nnoremap [gina] <Nop>
vnoremap [gina] <Nop>
nmap <Leader>g [gina]
vmap <Leader>g [gina]
nmap <silent> [gina]b :<C-u>Gina blame<CR>
nmap <silent> [gina]s :<C-u>Gina status --group=gina<CR>
nmap <silent> [gina]c :<C-u>Gina commit<CR>
nmap <silent> [gina]d :<C-u>Gina diff --group=gina<CR>
nmap <silent> [gina]p :<C-u>GitPush<CR>
nmap <silent> [gina]x :Gina browse :<CR>
nmap <silent> [gina]y :Gina browse --yank :<CR>
vmap <silent> [gina]x :Gina browse --exact :<CR>
vmap <silent> [gina]y :Gina browse --yank --exact :<CR>

command! -nargs=0 GitPush call s:git_push()
command! -nargs=0 GitCreatePR call s:create_pr()
function! s:git_push() abort
  let l:current_branch = gina#component#repo#branch()
  execute('Gina! push -u origin ' . l:current_branch)
endfunction

function! s:create_pr() abort
  let l:remote_url = system('git remote get-url origin')
  if stridx(l:remote_url, "github.com") != -1
    call system('gh pr create --web')
  else
    " TODO: change the command
    call system('lab mr browse')
  endif
endfunction
" }}}

" {{{ nvim-autopairs
lua <<EOF
require('nvim-autopairs').setup({
  ignored_next_char = "[%w]"
})
EOF
" }}}

" {{{ silicon
let g:silicon = {
    \   'background':         '#FFFFFF',
    \ }
" }}}

" {{{ nvim-colorizer.lua
lua require'colorizer'.setup()
" }}}

" {{{ rust-tools
lua require('kitagry.rust')
" }}}

" {{{ quickrun
" let g:quickrun_config = {}
"
" if executable('poetry')
"   let s:python_path = trim(system('poetry env info -p'))
"   let g:quickrun_config.python = { 'command': s:python_path }
" endif
" }}}

" {{{ fuzzy-motion
nnoremap ss :FuzzyMotion<CR>
" }}}
