local vim = vim
local cmd = vim.cmd

-- general_setting
local function general_setting()
  cmd([[filetype plugin indent on]])

  -- バックアップファイルを作らない
  vim.o.backup = false
  -- スワップファイルを作らない
  vim.o.swapfile = false
  -- undoファイルを作らない
  vim.o.undofile = false
  -- 編集中のファイルが変更されたら自動で読み直す
  vim.o.autoread = true
  -- バッファが編集中でもその他のファイルを開けるようにする
  vim.o.hidden = true
  -- 入力中のコマンドをステータスに表示する
  vim.o.showcmd = true

  -- 不可視文字を可視化
  vim.o.list = true
  vim.opt.listchars = { tab = "▸ ", trail = "·" }
  -- Tab文字を半角スペースにする
  vim.o.expandtab = true
  -- 行頭以外のTab文字の表示幅（スペースいくつ分）
  vim.o.tabstop = 2
  -- 行頭でのTab文字の表示幅
  vim.o.shiftwidth = 2
  -- マウス無効化
  vim.o.mouse = ''
  -- 検索時の大文字小文字を気にしない
  vim.o.ignorecase = true
  -- カーソルがある行をハイライト
  vim.o.cursorline = true
  -- ヘルプ用の言語
  vim.o.helplang = 'ja,en'
  -- ターミナルの色
  vim.o.background = 'dark'
  vim.o.termguicolors = true

  vim.o.foldmethod = 'expr'
  vim.o.foldexpr = 'nvim_treesitter#foldexpr()'
  vim.o.foldenable = false
  vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
    callback = function ()
      if vim.fn.expand('%:t') == 'init.lua' then
        vim.o.foldlevel = 1
        vim.o.foldnestmax = 2
        vim.o.foldenable = true
      else
        vim.o.foldenable = false
      end
    end
  })

  if vim.fn.has('mac') == 1 then
    vim.opt.clipboard = 'unnamed'
  else
    vim.o.clipboard = vim.o.clipboard .. 'unnamedplus'
  end

  local remove_unnecessary_space = function()
    -- delete last spaces
    cmd([[%s/\s\+$//ge]])

    -- delete last blank lines
    while vim.fn.getline('$') == '' and #vim.fn.getline(0, '$') ~= 0 do
      cmd('$delete _')
    end
  end
  vim.api.nvim_create_autocmd({"BufWritePre"}, {
    callback = remove_unnecessary_space,
  })

  vim.api.nvim_create_augroup('filetype_indent', {})
  vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
    group = 'filetype_indent',
    pattern = {'*.py', '*.jl', '*.php', '*.java'},
    callback = function()
      vim.bo.tabstop = 4
      vim.bo.softtabstop = 4
      vim.bo.shiftwidth = 4
    end
  })
  vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
    group = 'filetype_indent',
    pattern = {'*.go', '*.rego'},
    callback = function()
      vim.bo.expandtab = false
    end
  })

  vim.api.nvim_create_augroup('cursor_column', {})
  vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
    group = 'cursor_column',
    pattern = {'*.yaml'},
    callback = function()
      vim.bo.cursorcolumn = true
    end
  })
end
general_setting()

-- key mapping
local function keymap_setting()
  vim.g.mapleader = ' '
  -- ヤンクの設定
  vim.keymap.set('n', 'Y', 'y$', {noremap = true})
  -- バッファ移動設定
  vim.keymap.set('n', ']b', ':bnext<CR>', {noremap = true})
  vim.keymap.set('n', ']B', ':blast<CR>', {noremap = true})
  vim.keymap.set('n', '[b', ':bprevious<CR>', {noremap = true})
  vim.keymap.set('n', '[B', ':bfirst<CR>', {noremap = true})
  -- quickfix
  vim.keymap.set('n', ']q', ':cnext<CR>', {noremap = true})
  vim.keymap.set('n', ']Q', ':clast<CR>', {noremap = true})
  vim.keymap.set('n', '[q', ':cprevious<CR>', {noremap = true})
  vim.keymap.set('n', '[Q', ':cfirst<CR>', {noremap = true})
  -- 折返し時に表示業単位で移動する
  vim.keymap.set('', 'j', 'gj', {noremap = true})
  vim.keymap.set('', 'k', 'gk', {noremap = true})
  vim.keymap.set('', 'gj', 'j', {noremap = true})
  vim.keymap.set('', 'gk', 'k', {noremap = true})

  vim.keymap.set('n', '<leader>t', ':<C-u>vsp term://zsh<CR>', {noremap = true})
  vim.keymap.set('n', '<leader>T', ':<C-u>sp term://zsh<CR>', {noremap = true})

  -- '%%'でアクティブなバッファのディレクトリを開いてくれる
  vim.keymap.set('c', '%%', "getcmdtype() == ':' ? expand('%:h').'/' : '%%'", {expr = true, noremap = true})

  vim.keymap.set('i', '<C-l>', '<C-G>U<Right>', {silent = true, noremap = true})
  vim.keymap.set('i', '<Left>', '<C-G>U<Left>', {silent = true, noremap = true})
  vim.keymap.set('i', '<Right>', '<C-G>U<Right>', {silent = true, noremap = true})

  vim.keymap.set('n', '<Esc><Esc>', ':nohlsearch<CR><Esc>', {noremap = true})

  vim.api.nvim_create_autocmd({'FileType'}, {
    pattern = 'help',
    callback = function()
      vim.keymap.set('n', 'q', '<C-w>c', {noremap = true, buffer = true})
    end
  })
  vim.api.nvim_create_autocmd({'FileType'}, {
    pattern = 'qf',
    callback = function()
      vim.keymap.set('n', 'q', ':<C-u>cclose<CR>', {noremap = true, buffer = true})
    end
  })

  vim.keymap.set('n', '[special_lang]', '<Nop>', {noremap = true})
  vim.keymap.set('n', '<leader>h', '[special_lang]', {silent = true, remap=true})

  vim.api.nvim_create_autocmd({'FileType'}, {
    pattern = 'go',
    callback = function()
      vim.keymap.set('n', '[special_lang]t', require("kitagry.go").toggle_test_file, {buffer = true, remap=true})
    end
  })
end
keymap_setting()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local function setup_cmp ()
  vim.o.completeopt = 'menuone,noinsert,noselect'
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
      { name = 'nvim_lua' },
      { name = 'vsnip' },
      {
        name = 'buffer',
        option = {
          get_bufnrs = get_bufnrs
        }
      },
      { name = 'nvim_lsp_signature_help' },
      { name = 'rg' },
    },

    formatting = {
      format = function(entry, vim_item)
        vim_item.menu = ({
          nvim_lsp = '[LSP]',
          nvim_lua = '[Lua]',
          vsnip = '[vsnip]',
          cmdline = '[cmdline]',
          path = '[path]',
          buffer = '[Buffer]',
          rg = '[rg]'
        })[entry.source.name]
        return vim_item
      end
    },
    preselect = cmp.PreselectMode.None,
  }

  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'cmdline' },
      { name = 'path' },
    }
  })

  cmp.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
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
end

local function setup_lsp()
  require("kitagry.lsp").setupLSP()

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local bufnr = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client.server_capabilities.completionProvider then
        vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
      end
      if client.server_capabilities.definitionProvider then
        vim.bo[bufnr].tagfunc = "v:lua.vim.lsp.tagfunc"
      end
    end,
  })

  vim.fn.sign_define("LspDiagnosticsErrorSign", { text = 'E>', texthl = 'Error' })
  vim.fn.sign_define("LspDiagnosticsWarningSign", { text = 'W>', texthl = 'WarningMsg' })
  vim.fn.sign_define("LspDiagnosticsInformationSign", { text = 'I>', texthl = 'LspDiagnosticsInformation' })
  vim.fn.sign_define("LspDiagnosticsHintSign", { text = 'H>', texthl = 'LspDiagnosticsHint' })

  local function lsp_format ()
    require("kitagry.lsp").code_action_sync("source.organizeImports")
    local timer = vim.loop.new_timer()
    timer:start(100, 0, vim.schedule_wrap(function()
      vim.lsp.buf.format({async=false})
    end))
  end

  vim.api.nvim_create_augroup('lsp_formatting', {})
  vim.api.nvim_create_autocmd({'BufWritePre'}, {
    group = 'lsp_formatting',
    pattern = {'*.go', '*.rs'},
    callback = lsp_format
  })
  vim.api.nvim_create_autocmd({'BufWritePre'}, {
    group = 'lsp_formatting',
    pattern = {'*.tsx', '*.ts', '*.jsx', '*.js', '*.py', '*.rego'},
    callback = function()
      vim.lsp.buf.format({async=false})
    end
  })
end

require("lazy").setup({
  {"sainnhe/sonokai",
    config = function()
      vim.g.sonokai_style = 'shusia'
      cmd.colorscheme('sonokai')
    end,
  },
  {"hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-vsnip",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp-signature-help",
      "lukas-reineke/cmp-rg",
    },
    config = function()
      setup_cmp()
      vim.keymap.set('i', '<C-x><C-o>', require('cmp').complete, {remap = false, expr=true})
    end,
  },
  {"hrsh7th/vim-vsnip",
    dependencies = {
      "hrsh7th/vim-vsnip-integ",
      "kitagry/vs-snippets",
    },
    config = function()
      vim.keymap.set({'i', 's'}, '<C-j>', function()
        return vim.fn['vsnip#jumpable'](1) and '<Plug>(vsnip-jump-next)' or '<C-j>'
      end, { expr = true })
      vim.keymap.set({'i', 's'}, '<C-k>', function()
        return vim.fn['vsnip#jumpable'](-1) and '<Plug>(vsnip-jump-prev)' or '<C-k>'
      end, { expr = true })
    end,
  },
  {"williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      setup_lsp()

      vim.keymap.set('n', '[vim-lsp]', '<Nop>', {noremap = true})
      vim.keymap.set('n', '<leader>l', '[vim-lsp]', {silent = true, remap=true})
      vim.keymap.set('n', '<c-]>', vim.lsp.buf.definition, {silent = true})
      vim.keymap.set('n', '<c-k>', vim.lsp.buf.signature_help, {silent = true})
      vim.keymap.set('n', '[e', vim.diagnostic.goto_prev, {silent = true,})
      vim.keymap.set('n', ']e', vim.diagnostic.goto_next, {silent = true})

      vim.keymap.set('n', '[vim-lsp]h', vim.lsp.buf.hover, {remap = true})
      vim.keymap.set('n', '[vim-lsp]r', vim.lsp.buf.rename, {remap = true})
      vim.keymap.set('n', '[vim-lsp]f', function()
        vim.lsp.buf.format({timeout_ms=5000})
      end, {remap = true, expr = true})
      vim.keymap.set('n', '[vim-lsp]e', function()
        require('telescope.builtin').lsp_references({ include_declaration = true })
      end, {remap = true, expr = true})
      vim.keymap.set('n', '[vim-lsp]t', vim.lsp.buf.type_definition, {remap = true})
      vim.keymap.set('n', '[vim-lsp]a', vim.lsp.buf.code_action, {remap = true})
      vim.keymap.set('n', '[vim-lsp]i', function()
        require('telescope.builtin').lsp_implementations()
      end, {remap = true, expr = true})
      vim.keymap.set('n', '[vim-lsp]q', function()
        print("restarting lsp...")
        vim.lsp.stop_client(vim.lsp.get_active_clients())
        local timer = vim.loop.new_timer()
        timer:start(100, 0, vim.schedule_wrap(function()
          vim.cmd('edit')
        end))
      end, {remap = true, expr = true})
      vim.keymap.set('n', '[vim-lsp]s', ':<C-u>LspInfo<CR>', {remap = true})
    end,
  },
  {"jose-elias-alvarez/null-ls.nvim",
    config = function ()
      local null_ls = require("null-ls")
      local util = require("kitagry.util")
      local has_poetry = util.search_files({'poetry.lock'})

      local function with_poetry (builtin)
        if has_poetry == nil then
          return builtin
        end

        return builtin.with({
          command = { 'poetry', 'run', builtin._opts.command },
        })
      end

      local function textlint_path()
        local path = util.search_files({'./node_modules/textlint/bin/textlint.js'})
        if path then
          return './node_modules/textlint/bin/textlint.js'
        end
        return 'textlint'
      end

      null_ls.setup({
        sources = {
          null_ls.builtins.code_actions.gomodifytags,
          with_poetry(null_ls.builtins.diagnostics.flake8),
          with_poetry(null_ls.builtins.formatting.yapf),
          with_poetry(null_ls.builtins.formatting.isort),
          null_ls.builtins.diagnostics.shellcheck,
          null_ls.builtins.code_actions.shellcheck,
          null_ls.builtins.diagnostics.textlint.with({
            cwd = function (params)
              return params.root:match('.textlintrc')
            end,
            filetypes = { 'markdown' },
            command = textlint_path(),
          })
        },
      })
    end
  },
  {"nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-github.nvim",
      "nvim-telescope/telescope-ghq.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local telescope = require('telescope')
      local builtin = require('telescope.builtin')
      local actions = require('telescope.actions')

      telescope.setup({defaults=require('telescope.themes').get_ivy({
        i = {
          ["<C-w>"] = actions.send_selected_to_qflist,
          ["<C-q>"] = actions.send_to_qflist,
        },
        n = {
          ["<C-w>"] = actions.send_selected_to_qflist,
          ["<C-q>"] = actions.send_to_qflist,
        },
        cache_picker = {
          num_pickers = -1,
        },
      })})
      vim.keymap.set('n', '[telescope]', '<Nop>', {noremap = true})
      vim.keymap.set('n', '<leader>f', '[telescope]', {silent = true, remap=true})
      vim.keymap.set('n', '[telescope]r', builtin.resume, {remap = true})
      vim.keymap.set('n', '[telescope]f', builtin.find_files, {remap = true})
      vim.keymap.set('n', '[telescope]g', builtin.live_grep, {remap = true})
      vim.keymap.set('n', '[telescope]]', builtin.grep_string, {remap = true})
      vim.keymap.set('n', '[telescope]d', builtin.lsp_document_symbols, {remap = true})
      vim.keymap.set('n', '[telescope]b', builtin.buffers, {remap = true})
      vim.keymap.set('n', '[telescope]t', builtin.filetypes, {remap = true})
      vim.keymap.set('n', '[telescope]h', builtin.help_tags, {remap = true})
      vim.keymap.set('n', '[telescope]a', builtin.git_branches, {remap = true})
      vim.keymap.set('n', '[telescope]c', builtin.command_history, {remap = true})
    end
  },
  {"nvim-treesitter/nvim-treesitter",
    config = function()
      require("kitagry.treesitter").setupTreesitter()
    end
  },
  {"machakann/vim-sandwich"},
  {"numToStr/Comment.nvim",
    config = function()
      require('Comment').setup()
    end
  },
  {"tyru/open-browser.vim",
    config = function()
      vim.keymap.set({'n', 'v'}, 'gx', '<Plug>(openbrowser-open)', {})
    end
  },
  {"kana/vim-repeat"},
  {"kana/vim-textobj-user",
    dependencies = {
      "sgur/vim-textobj-parameter",
      "Julian/vim-textobj-variable-segment",
    },
  },
  {"lambdalisue/gina.vim",
    dependencies = {
      "kitagry/gina-openpr.vim",
    },
    config = function()
      vim.o.diffopt = 'vertical'
      vim.g["gina#command#blame#formatter#format"] = "%su%=by %au %ma%in"

      local git_push = function()
        local current_branch = vim.fn["gina#component#repo#branch"]()
        if current_branch == 'master' or current_branch == 'main' then
          local prompt = string.format('this wille push to %s? [y/N]', current_branch)
          vim.ui.input({ prompt = prompt, default = 'n' }, function (input)
            if string.lower(input) == 'y' then
              vim.cmd(string.format('Gina! push -u origin %s', current_branch))
            end
          end)
        else
          vim.cmd(string.format('Gina! push -u origin %s', current_branch))
        end
      end

      local create_pr = function()
        local remote_url = vim.fn.system([[!git remote get-url origin]])
        local ind = string.find(remote_url, 'github.com')
        if ind ~= nil then
          vim.fn.system([[gh pr create --web]])
        else
          print(string.format('not support for %s', remote_url))
        end
      end
      vim.api.nvim_create_user_command('GitCreatePR', create_pr, {})

      vim.keymap.set({'n', 'v'}, '[gina]', '<Nop>', {noremap = true})
      vim.keymap.set({'n', 'v'}, '<leader>g', '[gina]', {silent = true, remap=true})
      vim.keymap.set('n', '[gina]b', ':<C-u>Gina blame<CR>', {remap=true})
      vim.keymap.set('n', '[gina]s', ':<C-u>Gina status --group=gina<CR>', {remap=true})
      vim.keymap.set('n', '[gina]c', ':<C-u>Gina commit<CR>', {remap=true})
      vim.keymap.set('n', '[gina]d', ':<C-u>Gina diff --group=gina<CR>', {remap=true})
      vim.keymap.set('n', '[gina]p', git_push, {remap=true, expr=true})
      vim.keymap.set('n', '[gina]x', ':<C-u>Gina browse :<CR>', {remap=true})
      vim.keymap.set('n', '[gina]y', ':<C-u>Gina browse --yank :<CR>', {remap=true})
      vim.keymap.set('v', '[gina]x', ':<C-u>Gina blame --exact :<CR>', {remap=true})
      vim.keymap.set('v', '[gina]y', ':<C-u>Gina blame --exact --yank :<CR>', {remap=true})
    end
  },
  {"lambdalisue/fern.vim",
    dependencies = {
      "lambdalisue/nerdfont.vim",
      "lambdalisue/fern-hijack.vim",
      "lambdalisue/fern-renderer-nerdfont.vim",
    },
    config = function()
      vim.keymap.set('n', '[fern]', '<Nop>', {noremap = true})
      vim.keymap.set('n', '<leader>d', '[fern]', {silent = true, remap=true})
      vim.keymap.set('n', '[fern]a', ':<C-u>Fern . -drawer -toggle -reveal=%<CR>', {remap=true, silent=true})
      vim.keymap.set('n', '[fern]f', ':<C-u>Fern %:h -opener=edit<CR>', {remap=true, silent=true})
      vim.keymap.set('n', '[fern]v', ':<C-u>Fern . -opener=vsplit<CR>', {remap=true, silent=true})
      vim.keymap.set('n', '[fern]h', ':<C-u>Fern %:h -opener=vsplit<CR>', {remap=true, silent=true})
      vim.keymap.set('n', '[fern]m', ':<C-u>Fern ~/drive -drawer -toggle -reveal=%<CR>', {remap=true, silent=true})

      vim.g['fern#renderer'] = 'nerdfont'

      local init_fern = function()
        vim.keymap.set('n', 'R', '<Plug>(fern-action-remove)', {remap=true, buffer=true})
        vim.keymap.set('n', 'r', '<Plug>(fern-action-rename)', {remap=true, buffer=true})
      end

      vim.api.nvim_create_augroup('my-fern', {})
      vim.api.nvim_create_autocmd({'FileType'}, {
        group = 'my-fern',
        pattern = {'fern'},
        callback = function()
          init_fern()
        end
      })
    end
  },
  {"lambdalisue/reword.vim"},
  {"mattn/vim-goaddtags"},
  {"mattn/vim-goimpl"},
  {"haya14busa/vim-operator-flashy",
    dependencies = {
      "kana/vim-operator-user",
    },
    config = function()
      vim.keymap.set("", "y", "<Plug>(operator-flashy)", {remap=true})
      vim.keymap.set("n", "Y", "<Plug>(operator-flashy)$", {remap=true})
      vim.cmd([[hi Flashy term=bold ctermbg=0 guibg=#AA354A]])
      vim.g["operator#flashy#flash_time"] = 200
    end
  },
  {"windwp/nvim-autopairs",
    config = function()
      require('nvim-autopairs').setup({
        ignored_next_char = "[%w]"
      })
    end
  },
  {"monkoose/matchparen.nvim",
    config = function()
      require("matchparen").setup()
    end
  },
  {"lambdalisue/pastefix.vim"},
  {"norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup()
    end
  },
  {"scalameta/nvim-metals",
    config = function()
      vim.api.nvim_create_augroup('NvimMetals', {})
      vim.api.nvim_create_autocmd({"FileType"}, {
        group = 'NvimMetals',
        pattern = {'scala'},
        callback = function()
          require('metals').initialize_or_attach({})
        end
      })
    end
  },
  {"stevearc/overseer.nvim",
    config = function()
      require("overseer").setup({
        templates = { "builtin", "go" },
        component_aliases = {
          default = {
            { "on_output_quickfix", open_on_match = true },
            "on_output_summarize",
            "on_exit_set_status",
            "on_complete_notify",
            "on_complete_dispose",
          }
        },
      })
      vim.api.nvim_create_user_command("OverseerRestartLast", function()
        local overseer = require("overseer")
        local tasks = overseer.list_tasks({ recent_first = true })
        if vim.tbl_isempty(tasks) then
          vim.notify("No tasks found", vim.log.levels.WARN)
        else
          overseer.run_action(tasks[1], "restart")
        end
      end, {})

      vim.keymap.set('n', '[overseer]', '<Nop>', {noremap = true})
      vim.keymap.set('n', '<leader>q', '[overseer]', {silent = true, remap=true})
      vim.keymap.set('n', '[overseer]q', ':<C-u>OverseerRun<CR>', {remap=true, silent=true})
      vim.keymap.set('n', '[overseer]r', ':<C-u>OverseerRestartLast<CR>', {remap=true, silent=true})
    end
  }
})
