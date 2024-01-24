local vim = vim
local cmd = vim.cmd

require("kitagry.lazy").setup({
  { "general setting",
    setting = true,
    config = function()
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

      vim.o.encoding = 'utf-8'
      vim.o.fileencodings = 'utf-8,iso-2022-jp,euc-jp,sjis'

      if vim.fn.has('mac') == 1 then
        vim.opt.clipboard = 'unnamed'
      else
        vim.o.clipboard = vim.o.clipboard .. 'unnamedplus'
      end
    end,
  },
  { "fold setting",
    setting = true,
    config = function()
      vim.o.foldmethod = 'expr'
      vim.o.foldexpr = 'nvim_treesitter#foldexpr()'
      vim.o.foldenable = false
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        callback = function()
          if vim.fn.expand('%:t') == 'init.lua' then
            vim.o.foldlevel = 1
            vim.o.foldnestmax = 2
            vim.o.foldenable = true
          else
            vim.o.foldenable = false
          end
        end
      })
    end,
  },
  { "remove unnecessary spaces",
    setting = true,
    config = function()
      local remove_unnecessary_space = function()
        -- delete last spaces
        cmd([[%s/\s\+$//ge]])

        -- delete last blank lines
        while vim.fn.getline('$') == '' and #vim.fn.getline(0, '$') > 1 do
          cmd('$delete _')
        end
      end
      vim.api.nvim_create_autocmd({ "BufWritePre" }, {
        callback = remove_unnecessary_space,
      })
    end,
  },
  { "indent setting",
    setting = true,
    config = function()
      vim.api.nvim_create_augroup('filetype_indent', {})
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        group = 'filetype_indent',
        pattern = { '*.py', '*.jl', '*.php', '*.java' },
        callback = function()
          vim.bo.tabstop = 4
          vim.bo.softtabstop = 4
          vim.bo.shiftwidth = 4
        end
      })
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        group = 'filetype_indent',
        pattern = { '*.go', '*.rego' },
        callback = function()
          vim.bo.expandtab = false
        end
      })
    end,
  },
  { "cursor highlight setting",
    setting = true,
    config = function()
      vim.api.nvim_create_augroup('cursor_column', {})
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        group = 'cursor_column',
        pattern = { '*' },
        callback = function()
          local ft = vim.filetype.match({ buf = 0 })
          if ft == nil then
            vim.wo.cursorcolumn = false
            return
          end

          if vim.startswith(ft, 'yaml') then
            vim.wo.cursorcolumn = true
          else
            vim.wo.cursorcolumn = false
          end
        end
      })
    end,
  },
  { "filetype setting",
    setting = true,
    config = function()
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        pattern = { '*.tf', '*.tfvars' },
        callback = function()
          vim.bo.filetype = 'terraform'
        end
      })
      vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        pattern = { '*.pyi' },
        callback = function()
          vim.bo.filetype = 'python'
        end
      })
    end,
  },
  { "key mappings",
    setting = true,
    config = function()
      vim.g.mapleader = ' '
      -- ヤンクの設定
      vim.keymap.set('n', 'Y', 'y$')
      -- バッファ移動設定
      vim.keymap.set('n', ']b', ':bnext<CR>')
      vim.keymap.set('n', ']B', ':blast<CR>')
      vim.keymap.set('n', '[b', ':bprevious<CR>')
      vim.keymap.set('n', '[B', ':bfirst<CR>')
      -- tab
      vim.keymap.set('n', ']t', ':tabnext<CR>')
      vim.keymap.set('n', ']T', ':tablast<CR>')
      vim.keymap.set('n', '[t', ':tabprevious<CR>')
      vim.keymap.set('n', '[T', ':tabfirst<CR>')
      -- quickfix
      vim.keymap.set('n', ']q', ':cnext<CR>')
      vim.keymap.set('n', ']Q', ':clast<CR>')
      vim.keymap.set('n', '[q', ':cprevious<CR>')
      vim.keymap.set('n', '[Q', ':cfirst<CR>')
      -- 折返し時に表示業単位で移動する
      vim.keymap.set('', 'j', 'gj')
      vim.keymap.set('', 'k', 'gk')
      vim.keymap.set('', 'gj', 'j')
      vim.keymap.set('', 'gk', 'k')

      -- '%%'でアクティブなバッファのディレクトリを開いてくれる
      vim.keymap.set('c', '%%', "getcmdtype() == ':' ? expand('%:h').'/' : '%%'", { expr = true })

      vim.keymap.set('i', '<C-l>', '<C-G>U<Right>', { silent = true })
      vim.keymap.set('i', '<Left>', '<C-G>U<Left>', { silent = true })
      vim.keymap.set('i', '<Right>', '<C-G>U<Right>', { silent = true })

      vim.keymap.set('n', '<Esc><Esc>', ':nohlsearch<CR><Esc>')

      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'help',
        callback = function()
          vim.keymap.set('n', 'q', '<C-w>c', { buffer = true })
        end
      })
      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'qf',
        callback = function()
          vim.keymap.set('n', 'q', ':<C-u>cclose<CR>', { buffer = true })
        end
      })

      vim.keymap.set('n', '[special_lang]', '<Nop>')
      vim.keymap.set('n', '<leader>h', '[special_lang]', { silent = true, remap = true })

      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'go',
        callback = function()
          vim.keymap.set('n', '[special_lang]t', require("kitagry.go").toggle_test_file, { buffer = true, remap = true })
        end
      })
    end,
  },
  { "sainnhe/sonokai",
    cond = vim.fn.exists('g:vscode') == 0,
    config = function()
      vim.g.sonokai_style = 'shusia'
      cmd.colorscheme('sonokai')
    end,
  },
  { "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp-signature-help",
      "hrsh7th/cmp-emoji",
      "lukas-reineke/cmp-rg",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-copilot",
      "github/copilot.vim",
    },
    cond = vim.fn.exists('g:vscode') == 0,
    config = function()
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
            require('luasnip').lsp_expand(args.body)
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
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
          })
        },

        sources = {
          { name = 'copilot' },
          { name = 'nvim_lsp' },
          { name = 'nvim_lua' },
          { name = 'luasnip' },
          {
            name = 'buffer',
            option = {
              get_bufnrs = get_bufnrs
            }
          },
          { name = 'nvim_lsp_signature_help' },
          { name = 'rg', option = { additional_arguments = '--max-depth 3 --hidden' } },
          { name = 'emoji' },
        },

        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              copilot = '[copilot]',
              nvim_lsp = '[LSP]',
              nvim_lua = '[Lua]',
              luasnip = '[luasnip]',
              cmdline = '[cmdline]',
              path = '[path]',
              buffer = '[Buffer]',
              rg = '[rg]',
              emoji = '[emoji]',
            })[entry.source.name]
            return vim_item
          end
        },

        sorting = {
          comparators = {
            cmp.config.compare.offset,
            cmp.config.compare.exact,
            cmp.config.compare.score,
            function (entry1, entry2)
              local types = require('cmp.types')
              local kind1 = entry1:get_kind()
              kind1 = kind1 == types.lsp.CompletionItemKind.Text and 100 or kind1
              kind1 = kind1 == types.lsp.CompletionItemKind.Field and 0 or kind1
              local kind2 = entry2:get_kind()
              kind2 = kind2 == types.lsp.CompletionItemKind.Text and 100 or kind2
              kind2 = kind2 == types.lsp.CompletionItemKind.Field and 0 or kind2
              if kind1 ~= kind2 then
                if kind1 == types.lsp.CompletionItemKind.Snippet then
                  return true
                end
                if kind2 == types.lsp.CompletionItemKind.Snippet then
                  return false
                end
                local diff = kind1 - kind2
                if diff < 0 then
                  return true
                elseif diff > 0 then
                  return false
                end
              end
            end,
            cmp.config.compare.sort_text,
            cmp.config.compare.length,
            cmp.config.compare.order,
          },
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
      vim.keymap.set('i', '<C-x><C-o>', require('cmp').complete, { remap = false })
    end,
  },
  { -- Neovim LSP
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
      "folke/neodev.nvim",
    },
    init = function()
      vim.keymap.set('n', '[vim-lsp]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>l', '[vim-lsp]', { silent = true, remap = true })
      if vim.fn.exists('g:vscode') == 1 then
        vim.keymap.set('n', 'c-]', "<cmd>call VSCodeNotify('editor.action.revealDefinition')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[e', "<cmd>call VSCodeNotify('editor.action.marker.prev')<CR>", { silent = true, expr = true })
        vim.keymap.set('n', ']e', "<cmd>call VSCodeNotify('editor.action.marker.next')<CR>", { silent = true, expr = true })

        vim.keymap.set('n', '[vim-lsp]h', "<cmd>call VSCodeNotify('editor.action.revealDefinition')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[vim-lsp]r', "<cmd>call VSCodeNotify('editor.action.rename')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[vim-lsp]f', "<cmd>call VSCodeNotify('editor.action.formatDocument')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[vim-lsp]t', "<cmd>call VSCodeNotify('editor.action.goToTypeDefinition')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[vim-lsp]e', "<cmd>call VSCodeNotify('references-view.findReferences')<CR>",
          { silent = true, expr = true })
        vim.keymap.set('n', '[vim-lsp]a', "<cmd>call VSCodeNotify('editor.action.sourceAction')<CR>",
          { silent = true, expr = true })
      else

        vim.keymap.set('n', '<c-]>', vim.lsp.buf.definition, { silent = true })
        vim.keymap.set('n', '<c-k>', vim.lsp.buf.signature_help, { silent = true })
        vim.keymap.set('n', '[e', vim.diagnostic.goto_prev, { silent = true, })
        vim.keymap.set('n', ']e', vim.diagnostic.goto_next, { silent = true })

        vim.keymap.set('n', '[vim-lsp]v', function()
          require("telescope.builtin").lsp_definitions({jump_type='vsplit'})
        end)
        vim.keymap.set('n', '[vim-lsp]h', vim.lsp.buf.hover, { remap = true })
        vim.keymap.set('n', '[vim-lsp]r', vim.lsp.buf.rename, { remap = true })
        vim.keymap.set('n', '[vim-lsp]f', function()
          vim.lsp.buf.format({ timeout_ms = 5000 })
        end, { remap = true, silent = true })
        vim.keymap.set('n', '[vim-lsp]e', function()
          require('telescope.builtin').lsp_references({ include_declaration = true })
        end, { remap = true })
        vim.keymap.set('n', '[vim-lsp]t', vim.lsp.buf.type_definition, { remap = true })
        vim.keymap.set('n', '[vim-lsp]a', vim.lsp.buf.code_action, { remap = true })
        vim.keymap.set('n', '[vim-lsp]i', function()
          require('telescope.builtin').lsp_implementations()
        end, { remap = true })
        vim.keymap.set('n', '[vim-lsp]q', function()
          print("restarting lsp...")
          vim.lsp.stop_client(vim.lsp.get_active_clients())
          vim.cmd("sleep 100ms")
          vim.cmd('edit')
        end, { remap = true })
        vim.keymap.set('n', '[vim-lsp]s', ':<C-u>LspInfo<CR>', { remap = true })
      end
    end,
    config = function()
      if vim.fn.exists('g:vscode') == 1 then
        return
      end
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

      local function lsp_format()
        require("kitagry.lsp").code_action_sync("source.organizeImports")
        vim.lsp.buf.format({ async = false })
      end

      vim.api.nvim_create_augroup('lsp_formatting', {})
      vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
        group = 'lsp_formatting',
        pattern = { '*.go', '*.rs' },
        callback = lsp_format
      })
      vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
        group = 'lsp_formatting',
        pattern = { '*.tsx', '*.ts', '*.jsx', '*.js', '*.py', '*.rego' },
        callback = function()
          vim.lsp.buf.format({ async = false, timeout_ms = 3000 })
        end
      })
    end,
  },
  { "jose-elias-alvarez/null-ls.nvim",
    config = function()
      local null_ls = require("null-ls")
      local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
      local poetry_lock_path = vim.fn.findfile('poetry.lock', parent .. ';')
      local util = require("kitagry.util")

      local function with_poetry(builtin, command)
        if not poetry_lock_path then
          return builtin
        end

        return builtin.with({
          command = { 'poetry', 'run', command },
        })
      end

      local function with_pflake8(builtin)
        local command = 'flake8'
        local path = util.search_files({ 'pyproject.toml' })
        if path == nil then
          return with_poetry(builtin, command)
        end

        local content = util.read_file(path .. '/pyproject.toml')
        if content == nil then
          return with_poetry(builtin, command)
        end

        for line in vim.gsplit(content, "\n") do
          local pflake8 = vim.startswith(line, 'pyproject-flake8')
          if pflake8 then
            command = 'pflake8'
          end
        end

        return with_poetry(builtin, command)
      end

      local function formatter_for_python()
        if not poetry_lock_path then
          return null_ls.builtins.formatting.black
        end

        local path = util.search_files({ 'pyproject.toml' })
        if path == nil then
          return null_ls.builtins.formatting.black
        end

        local content = util.read_file(path .. '/pyproject.toml')
        if content == nil then
          return null_ls.builtins.formatting.black
        end

        for line in vim.gsplit(content, "\n") do
          if vim.startswith(line, "black") then
            return with_poetry(null_ls.builtins.formatting.black, 'black')
          elseif vim.startswith(line, "yapf") then
            return with_poetry(null_ls.builtins.formatting.yapf, 'yapf')
          end
        end
      end

      local sources = {
        null_ls.builtins.code_actions.gomodifytags,
        with_pflake8(null_ls.builtins.diagnostics.flake8),
        formatter_for_python(),
        with_poetry(null_ls.builtins.formatting.isort, 'isort'),
        null_ls.builtins.diagnostics.shellcheck,
        null_ls.builtins.code_actions.shellcheck,
      }

      local function textlint_path()
        local path = util.search_files({ './node_modules/textlint/bin/textlint.js' })
        if path then
          return './node_modules/textlint/bin/textlint.js'
        end
        return 'textlint'
      end

      local has_textlint = util.search_files({ 'package.json' })
      if has_textlint ~= nil then
        sources = vim.list_extend(sources, {
          null_ls.builtins.diagnostics.textlint.with({
            cwd = function(params)
              return params.root:match('.textlintrc')
            end,
            filetypes = { 'markdown', 'review' },
            command = textlint_path(),
          })
        })
      end

      null_ls.setup({
        sources = sources,
      })
    end
  },
  { "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-github.nvim",
      "nvim-telescope/telescope-ghq.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    init = function()
      local builtin = require('telescope.builtin')

      vim.keymap.set('n', '[telescope]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>f', '[telescope]', { silent = true, remap = true })
      vim.keymap.set('n', '[telescope]r', builtin.resume, { remap = true })
      vim.keymap.set('n', '[telescope]f', builtin.find_files, { remap = true })
      vim.keymap.set('n', '[telescope]g', builtin.live_grep, { remap = true })
      vim.keymap.set('n', '[telescope]]', builtin.grep_string, { remap = true })
      vim.keymap.set('n', '[telescope]d', builtin.lsp_document_symbols, { remap = true })
      vim.keymap.set('n', '[telescope]b', builtin.buffers, { remap = true })
      vim.keymap.set('n', '[telescope]t', builtin.filetypes, { remap = true })
      vim.keymap.set('n', '[telescope]h', builtin.help_tags, { remap = true })
      vim.keymap.set('n', '[telescope]a', builtin.git_branches, { remap = true })
      vim.keymap.set('n', '[telescope]c', builtin.command_history, { remap = true })
    end,
    cond = vim.fn.exists('g:vscode') == 0,
    event = { "BufNewFile", "BufRead" },
    config = function()
      local telescope = require('telescope')
      local actions = require('telescope.actions')

      telescope.setup({ defaults = require('telescope.themes').get_ivy({
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
      }) })
    end
  },
  { "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/playground"
    },
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = 'all',
        ignore_install = { 'haskell' },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = { 'org' },
        },
        playground = {
          enable = true,
          disable = {},
          updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
          persist_queries = false -- Whether the query persists across vim sessions
        },
        textobjects = {
          select = {
            enable = true,
            keymaps = {
              ["if"] = "@function.inner",
              ["af"] = "@function.outer",
              ["ic"] = "@class.inner",
              ["ac"] = "@class.outer",
              ["i,"] = "@parameter.inner",
              ["a,"] = "@parameter.outer",
            },
          },
          swap = {
            enable = true,
            swap_next = {
              ["<leader>sp"] = "@parameter.inner",
              ["<leader>sf"] = "@function.outer",
              ["<leader>sc"] = "@class.outer",
            },
            swap_previous = {
              ["<leader>sP"] = "@function.outer",
              ["<leader>sF"] = "@function.outer",
              ["<leader>sC"] = "@class.outer",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["]m"] = "@function.outer",
              ["]]"] = "@class.outer",
            },
            goto_next_end = {
              ["]M"] = "@function.outer",
              ["]["] = "@class.outer",
            },
            goto_previous_start = {
              ["[m"] = "@function.outer",
              ["[["] = "@class.outer",
            },
            goto_previous_end = {
              ["[M"] = "@function.outer",
              ["[]"] = "@class.outer",
            },
          },
          lsp_interop = {
            enable = true,
            border = "none",
            floating_preview_opts = {},
            peek_definition_code = {
              ["<leader>lf"] = "@function.outer",
              ["<leader>dF"] = "@class.outer",
            },
          },
        },
      }
    end
  },
  { "JoosepAlviste/nvim-ts-context-commentstring",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require('ts_context_commentstring').setup({
      })
    end
  },
  { "machakann/vim-sandwich" },
  { "numToStr/Comment.nvim",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      require('ts_context_commentstring').setup({
        enable_autocmd = false,
      })
      require('Comment').setup({
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
      })
    end
  },
  { "tyru/open-browser.vim",
    config = function()
      vim.keymap.set({ 'n', 'v' }, 'gx', '<Plug>(openbrowser-open)', {})
    end
  },
  { "kana/vim-repeat" },
  { "kana/vim-textobj-user",
    dependencies = {
      "Julian/vim-textobj-variable-segment",
    },
  },
  { "lambdalisue/gina.vim",
    dependencies = {
      "kitagry/gina-openpr.vim",
    },
    init = function()
      local git_push = function()
        local current_branch = vim.fn["gina#component#repo#branch"]()
        if current_branch == 'master' or current_branch == 'main' then
          local prompt = string.format('this wille push to %s? [y/N]', current_branch)
          vim.ui.input({ prompt = prompt }, function(input)
            if string.lower(input) == 'y' then
              vim.cmd(string.format('Gina! push -u origin %s', current_branch))
            end
          end)
        else
          vim.cmd(string.format('Gina! push -u origin %s', current_branch))
        end
      end

      vim.keymap.set({ 'n', 'v' }, '[gina]', '<Nop>', { noremap = true })
      vim.keymap.set({ 'n', 'v' }, '<leader>g', '[gina]', { silent = true, remap = true })
      vim.keymap.set('n', '[gina]b', ':Gina blame<CR>', { remap = true })
      vim.keymap.set('n', '[gina]s', ':Gina status --group=gina<CR>', { remap = true })
      vim.keymap.set('n', '[gina]c', ':Gina commit<CR>', { remap = true })
      vim.keymap.set('n', '[gina]d', ':Gina diff --group=gina<CR>', { remap = true })
      vim.keymap.set('n', '[gina]p', git_push, { remap = true })
      vim.keymap.set('n', '[gina]x', ':Gina browse :<CR>', { remap = true })
      vim.keymap.set('n', '[gina]y', ':Gina browse --yank :<CR>', { remap = true })
      vim.keymap.set('v', '[gina]x', ':Gina browse --exact :<CR>', { remap = true })
      vim.keymap.set('v', '[gina]y', ':Gina browse --exact --yank :<CR>', { remap = true })
    end,
    config = function()
      vim.o.diffopt = 'vertical'
      vim.g["gina#command#blame#formatter#format"] = "%su%=by %au %ma%in"

      local create_pr = function()
        local remote_url = vim.fn.system([[git remote get-url origin]])
        local ind = string.find(remote_url, 'github.com')
        if ind ~= nil then
          vim.fn.system([[gh pr create --web]])
        else
          print(string.format('not support for %s', remote_url))
        end
      end
      vim.api.nvim_create_user_command('GitCreatePR', create_pr, {})
    end
  },
  { "lambdalisue/fern.vim",
    dependencies = {
      "lambdalisue/nerdfont.vim",
      "lambdalisue/fern-hijack.vim",
      "lambdalisue/fern-renderer-nerdfont.vim",
    },
    -- cmd = {'Fern'}, for fern-hijack
    init = function()
      vim.keymap.set('n', '[fern]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>d', '[fern]', { silent = true, remap = true })
      vim.keymap.set('n', '[fern]a', ':<C-u>Fern . -drawer -toggle -reveal=%<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[fern]f', ':<C-u>Fern %:h -opener=edit<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[fern]v', ':<C-u>Fern . -opener=vsplit<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[fern]h', ':<C-u>Fern %:h -opener=vsplit<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[fern]m', ':<C-u>Fern ~/drive -drawer -toggle -reveal=%<CR>', { remap = true, silent = true })
    end,
    config = function()
      vim.g['fern#renderer'] = 'nerdfont'

      local init_fern = function()
        vim.keymap.set('n', 'R', '<Plug>(fern-action-remove)', { remap = true, buffer = true })
        vim.keymap.set('n', 'r', '<Plug>(fern-action-rename)', { remap = true, buffer = true })
      end

      vim.api.nvim_create_augroup('my-fern', {})
      vim.api.nvim_create_autocmd({ 'FileType' }, {
        group = 'my-fern',
        pattern = { 'fern' },
        callback = function()
          init_fern()
        end
      })
    end
  },
  { "lambdalisue/reword.vim" },
  { "mattn/vim-goaddtags", ft = "go" },
  { "mattn/vim-goimpl", ft = "go" },
  { "haya14busa/vim-operator-flashy",
    dependencies = {
      "kana/vim-operator-user",
    },
    config = function()
      vim.keymap.set("", "y", "<Plug>(operator-flashy)", { remap = true })
      vim.keymap.set("n", "Y", "<Plug>(operator-flashy)$", { remap = true })
      vim.cmd([[hi Flashy term=bold ctermbg=0 guibg=#AA354A]])
      vim.g["operator#flashy#flash_time"] = 200
    end
  },
  { "windwp/nvim-autopairs",
    event = { "InsertEnter" },
    config = function()
      require('nvim-autopairs').setup({
        ignored_next_char = "[%w]"
      })
    end
  },
  { "monkoose/matchparen.nvim",
    config = function()
      require("matchparen").setup()
    end
  },
  { "lambdalisue/pastefix.vim" },
  { "norcalli/nvim-colorizer.lua",
    event = { "BufNewFile", "BufRead" },
    config = function()
      require("colorizer").setup()
    end
  },
  { "scalameta/nvim-metals",
    config = function()
      vim.api.nvim_create_augroup('NvimMetals', {})
      vim.api.nvim_create_autocmd({ "FileType" }, {
        group = 'NvimMetals',
        pattern = { 'scala' },
        callback = function()
          require('metals').initialize_or_attach({})
        end
      })
    end
  },
  { "stevearc/dressing.nvim",
    config = function()
      require("dressing").setup()
    end
  },
  { "stevearc/overseer.nvim",
    config = function()
      require("overseer").setup({
        templates = { "go", "python", "make", "javascript" },
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

      vim.keymap.set('n', '[overseer]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>q', '[overseer]', { silent = true, remap = true })
      vim.keymap.set('n', '[overseer]q', ':<C-u>OverseerRun<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[overseer]r', ':<C-u>OverseerRestartLast<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[overseer]t', ':<C-u>OverseerToggle<CR>', { remap = true, silent = true })
    end
  },
  { "nvim-lualine/lualine.nvim",
    dependencies = {
      "arkav/lualine-lsp-progress",
    },
    config = function()
      require("lualine").setup({
        icons_enabled = false,
        sections = {
          lualine_a = { 'mode' },
          lualine_b = {
            'branch',
            'diff',
            {
              'diagnostics',
              symbols = {
                error = 'E:',
                warn = 'W:',
                info = 'I:',
                hint = 'H:',
              }
            }
          },
          lualine_c = { {'filename', path = 1}, 'lsp_progress' },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' }
        },
        tabline = {
          lualine_a = {
            {
              'buffers',
              show_filename_only = false,
            }
          },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = { 'tabs' }
        }
      })
    end
  },
  { "akinsho/toggleterm.nvim",
    cmd = { 'ToggleTerm' },
    init = function()
      vim.keymap.set('n', '<C-j>', '<cmd>exe v:count1 . "ToggleTerm direction=horizontal"<CR>', {})
      vim.keymap.set('n', '<leader>t', '<cmd>exe v:count1 . "ToggleTerm direction=float"<CR>', {})
    end,
    config = function()
      require("toggleterm").setup({
        start_in_insert = false,
        autochdir = true,
        auto_scroll = false
      })

      vim.api.nvim_create_augroup('toggleterm', {})
      vim.api.nvim_create_autocmd({ 'TermEnter' }, {
        pattern = { 'term://*toggleterm#*' },
        callback = function()
          vim.keymap.set('t', '<C-j>', '<cmd>exe v:count1 . "ToggleTerm"<CR>', {})
        end
      })
    end
  },
  { "lewis6991/gitsigns.nvim",
    config = function ()
      local gitsigns = require('gitsigns')
      gitsigns.setup({
        current_line_blame = true,
      })
      vim.keymap.set('n', ']c', gitsigns.next_hunk)
      vim.keymap.set('n', '[c', gitsigns.prev_hunk)
    end
  },
  { "oky-123/marksign.vim" },
  { "tokorom/vim-review" },
  { "L3MON4D3/LuaSnip",
    dependencies = {
      'rafamadriz/friendly-snippets',
    },
    version = "1.*",
    build = "make install_jsregexp",
    config = function ()
      local luasnip = require('luasnip')
      vim.keymap.set({'i'}, '<Tab>', function()
        return vim.fn['luasnip#expand_or_jumpable']() and '<Plug>luasnip-expand-or-jump' or '<Tab>'
      end, { expr = true, remap = true })
      vim.keymap.set({'s'}, '<Tab>', function()
        luasnip.jump(1)
      end)
      vim.keymap.set({'i', 's'}, '<S-Tab>', function()
        luasnip.jump(-1)
      end)
      require("luasnip.loaders.from_vscode").lazy_load()
      require("luasnip.loaders.from_vscode").load({ paths = "~/.vim/vsnip" })
      require("kitagry.snippet")
    end
  },
  { "rcarriga/nvim-notify",
    config = function()
      vim.notify = require("notify")
    end
  },
})

local local_path = vim.env.HOME .. '/.config/nvim/init.local.lua'
if require("kitagry.util").exists(local_path) then
  vim.cmd('source ' .. local_path)
end
