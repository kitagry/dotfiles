local vim = vim
local cmd = vim.cmd

local local_path = vim.env.HOME .. '/.config/nvim/init.local.vim'
vim.cmd('source ' .. local_path)

local local_path = vim.env.HOME .. '/.config/nvim/init.local.lua'
if require("kitagry.util").exists(local_path) then
  vim.cmd('source ' .. local_path)
end

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
      elseif vim.fn.has('wsl') then
        vim.opt.clipboard = 'unnamedplus'
        vim.g.clipboard = {
          name = 'WslClipboard',
          copy = {
            ["+"] = "win32yank.exe -i",
            ["*"] = "win32yank.exe -i",
          },
          paste = {
            ["+"] = "win32yank.exe -o",
            ["*"] = "win32yank.exe -o",
          },
        }
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
        pattern = { '*.go', '*.rego', 'go.mod' },
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
      vim.keymap.set('c', '%F', "getcmdtype() == ':' ? expand('%:p') : '%F'", { expr = true })

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

      vim.keymap.set('n', '<leader>yp', require("kitagry.util").yank_file_path, { desc = 'Yank file path' })
      vim.keymap.set('v', '<leader>yp', require("kitagry.util").yank_file_path, { desc = 'Yank file path with line numbers' })
    end,
  },
  { "sainnhe/sonokai",
    cond = vim.fn.exists('g:vscode') == 0,
    config = function()
      vim.g.sonokai_style = 'shusia'
      cmd.colorscheme('sonokai')
    end,
  },
  { "zbirenbaum/copilot.lua",
      cond = vim.fn.exists('g:vscode') == 0,
      cmd = "Copilot",
      event = "InsertEnter",
      config = function()
        require("copilot").setup({
          filetypes = {
            gitcommit = true,
          },
        })
      end,
  },
  { "zbirenbaum/copilot-cmp",
    cond = vim.fn.exists('g:vscode') == 0,
    dependencies = {
      "zbirenbaum/copilot.lua",
    },
    config = function()
      require("copilot_cmp").setup()
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
      "zbirenbaum/copilot-cmp",
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
          { name = 'path' },
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
  { "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "zbirenbaum/copilot.lua",
      "nvim-lua/plenary.nvim",
    },
    cond = vim.fn.exists('g:vscode') == 0,
    build = "make tiktoken",
    opts = {},
    keys = {
        { "<leader>cc", "<cmd>CopilotChatToggle<cr>", mode = { "n", "v" }, desc = "CopilotChat" },
        { "<leader>ca", "<cmd>CopilotChatAgents<cr>", mode = { "n", "v" }, desc = "CopilotChatAgents" },
        { "<leader>ct", "<cmd>CopilotChatPrompts<cr>", mode = { "n", "v" }, desc = "CopilotChatPrompts" },
    },
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
  { "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-github.nvim",
      "nvim-telescope/telescope-ghq.nvim",
      "nvim-telescope/telescope-frecency.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    init = function()
      local builtin = require('telescope.builtin')
      local action_state = require("telescope.actions.state")

      vim.keymap.set('n', '[telescope]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>f', '[telescope]', { silent = true, remap = true })
      vim.keymap.set('n', '[telescope]r', builtin.resume, { remap = true })
      vim.keymap.set('n', '[telescope]f', function()
        builtin.find_files({
          attach_mappings = function(_, map)
            map("i", "<C-h>", function(prompt_bufnr)
              local current_picker = action_state.get_current_picker(prompt_bufnr)
              local opts = current_picker:find("opts") or {}
              opts.hidden = not opts.hidden -- hiddenをトグル
              builtin.find_files(opts)
            end)
            return true
          end,
        })
      end, { remap = true })
      vim.keymap.set('n', '[telescope]g', function(_, map)
        builtin.live_grep({
          glob_pattern = '!.git',
          additional_args = function(opts)
            return {
              '--hidden',
              '--ignore-case'
            }
          end
        })
      end, { remap = true })
      vim.keymap.set('n', '[telescope]]', builtin.grep_string, { remap = true })
      vim.keymap.set('n', '[telescope]d', builtin.lsp_document_symbols, { remap = true })
      vim.keymap.set('n', '[telescope]b', builtin.buffers, { remap = true })
      vim.keymap.set('n', '[telescope]t', builtin.filetypes, { remap = true })
      vim.keymap.set('n', '[telescope]h', builtin.help_tags, { remap = true })
      vim.keymap.set('n', '[telescope]a', builtin.git_branches, { remap = true })
      vim.keymap.set('n', '[telescope]c', builtin.command_history, { remap = true })
      vim.keymap.set('n', '[telescope]q', ':<C-u>Telescope frecency workspace=CWD<CR>', { remap = true, silent = true })
    end,
    cond = vim.fn.exists('g:vscode') == 0,
    event = { "BufNewFile", "BufRead" },
    config = function()
      local telescope = require('telescope')
      local actions = require('telescope.actions')

      telescope.load_extension("frecency")
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
      "nvim-treesitter/playground",
      "andymass/vim-matchup"
    },
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = 'all',
        ignore_install = { 'haskell', 'ipkg' },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = { 'org' },
          disable = function(lang, buf)
              -- 100 KB 以上のファイルでは tree-sitter によるシンタックスハイライトを行わない
              local max_filesize = 100 * 1024
              local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
              if ok and stats and stats.size > max_filesize then
                  return true
              end
          end,
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
              ["il"] = "@loop.inner",
              ["al"] = "@loop.outer",
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
            -- peek_definition_code = {
            --   ["<leader>lf"] = "@function.outer",
            --   ["<leader>dF"] = "@class.outer",
            -- },
          },
        },
        matchup = {
          enable = true,
        },
      }
    end
  },
  { "machakann/vim-sandwich" },
  { "numToStr/Comment.nvim",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
      "nvim-treesitter/nvim-treesitter",
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
  { "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      "s1n7ax/nvim-window-picker",
      "kitagry/bqls.nvim",
    },
    init = function()
      vim.keymap.set('n', '[neotree]', '<Nop>', { noremap = true })
      vim.keymap.set('n', '<leader>d', '[neotree]', { silent = true, remap = true })
      vim.keymap.set('n', '[neotree]c', ':<C-u>Neotree toggle reveal<CR>', { remap = true, silent = true })
      vim.keymap.set('n', '[neotree]b', ':<C-u>Neotree toggle bqls<CR>', { remap = true, silent = true })
    end,
    config = function()
      require("neo-tree").setup({
        sources = {
          "filesystem",
          "buffers",
          "git_status",
          "bqls"
        },
        source_selector = {
            winbar = true,
            statusline = false
        },
        filesystem = {
          bind_to_cwd = false,
          window = {
            mappings = {
              -- disable fuzzy finder
              ["/"] = "noop"
            }
          }
        },
        bqls = {
          project_ids = vim.env.BQLS_PROJECT_IDS and vim.split(vim.env.BQLS_PROJECT_IDS, ",") or { "bigquery-public-data" },
        },
      })
    end
  },
  { "lambdalisue/gin.vim",
    dependencies = {
      "vim-denops/denops.vim",
      "nvim-telescope/telescope.nvim",
      "FabijanZulj/blame.nvim",
    },
    init = function()
      vim.keymap.set({ 'n', 'v' }, '[gin]', '<Nop>', { noremap = true })
      vim.keymap.set({ 'n', 'v' }, '<leader>g', '[gin]', { silent = true, remap = true })
      vim.keymap.set('n', '[gin]s', ':GinStatus<CR>', { remap = true })
      vim.keymap.set('n', '[gin]c', ':Gin commit<CR>', { remap = true })
      vim.keymap.set('n', '[gin]a', ':Gin commit --amend<CR>', { remap = true })
      vim.keymap.set('n', '[gin]l', ':GinLog --oneline<CR>', { remap = true })
      vim.keymap.set('n', '[gin]p', ':Gin push<CR>', { remap = true })
      vim.keymap.set('n', '[gin]d', ':GinDiff<CR>', { remap = true })
      vim.keymap.set({ 'n', 'v' }, '[gin]x', ':GinBrowse<CR>', { remap = true })
      vim.keymap.set({ 'n', 'v' }, '[gin]y', ':GinBrowse ++yank<CR>', { remap = true })

      require("blame").setup()
      vim.keymap.set('n', '[gin]b', ':BlameToggle<CR>', { remap = true })
    end,
    config = function()
      local augroup = vim.api.nvim_create_augroup('kitagry.gin', {})
      vim.api.nvim_create_autocmd('BufReadCmd', {
        group = augroup,
        pattern = { 'gin://*', 'ginedit://*', 'ginlog://*', 'gindiff://*', 'ginstatus://*' },
        callback = function(ctx)
          vim.keymap.set("n", "a", function()
            require("telescope.builtin").keymaps({ default_text = "gin-action " })
          end, { buffer = ctx.buf })
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
  -- { "windwp/nvim-autopairs",
  --   event = { "InsertEnter" },
  --   config = function()
  --     require('nvim-autopairs').setup({
  --       ignored_next_char = "[%w]"
  --     })
  --   end
  -- },
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
  { "folke/snacks.nvim",
    opts = {
      picker = {
        ui_select = true
      }
    },
    keys = {
        { "<leader>ghp", function() Snacks.gh.pr() end, desc = "ClaudeCode" },
        { "<leader>ghi", function() Snacks.gh.issue() end, desc = "ClaudeCode" },
    }
  },
  { "stevearc/overseer.nvim",
    cond = vim.fn.exists('g:vscode') == 0,
    config = function()
      require("overseer").setup({
        templates = { "rust", "go", "python", "make", "javascript" },
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
    cond = vim.fn.exists('g:vscode') == 0,
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
    cond = vim.fn.exists('g:vscode') == 0,
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
    opts = {
      current_line_blame = true,
    },
    keys = {
      { ']c', function() require('gitsigns').next_hunk() end, desc = 'gitsigns next hunk' },
      { '[c', function() require('gitsigns').prev_hunk() end, desc = 'gitsigns prev hunk' },
    },
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

      vim.keymap.set({"i", "s"}, "<C-j>", function ()
        if luasnip.jumpable(1) then
          return '<cmd>lua require("luasnip").jump(1)<cr>'
        else
          return '<C-j>'
        end
      end, { expr = true })
      vim.keymap.set({"i", "s"}, "<C-k>", function()
        if luasnip.jumpable(-1) then
          return '<cmd>lua require("luasnip").jump(-1)<cr>'
        else
          return '<C-j>'
        end
      end, { expr = true })
      require("luasnip.loaders.from_vscode").lazy_load()
      require("luasnip.loaders.from_vscode").load({ paths = "~/.vim/vsnip" })
      require("kitagry.snippet")
    end
  },
  { "rcarriga/nvim-notify",
    config = function()
      local notify = require("notify")
      notify.setup({
        max_width = 80,
      })
      vim.notify = notify
    end
  },
  { "kitagry/bqls.nvim",
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    cond = vim.fn.exists('g:vscode') == 0,
    config = function()
      vim.lsp.config('bqls', {
        capabilities = require("kitagry.lsp").capabilities,
        init_options = {
          project_id = os.getenv("BIGQUERY_GOOGLE_CLOUD_PROJECT") or "bigquery-public-data",
        }
      })
      vim.lsp.enable('bqls')
    end
  },
  { "iamcco/markdown-preview.nvim" },
  -- { "stevearc/oil.nvim",
  --   dependencies = {
  --     "echasnovski/mini.icons"
  --   },
  --   cond = vim.fn.exists('g:vscode') == 0,
  --   config = function ()
  --     -- Declare a global function to retrieve the current directory
  --     function _G.get_oil_winbar()
  --       local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  --       local dir = require("oil").get_current_dir(bufnr)
  --       if dir then
  --         return vim.fn.fnamemodify(dir, ":~")
  --       else
  --         -- If there is no current directory (e.g. over ssh), just show the buffer name
  --         return vim.api.nvim_buf_get_name(0)
  --       end
  --     end
  --
  --     require("oil").setup({
  --       delete_to_trash = true,
  --       keymaps = {
  --         ["<leader>ff"] = {
  --             function()
  --                 require("telescope.builtin").find_files({
  --                     cwd = require("oil").get_current_dir(),
  --                     hidden = true,
  --                 })
  --             end,
  --             mode = "n",
  --             nowait = true,
  --             desc = "Find files in the current directory"
  --         },
  --       },
  --       win_options = {
  --         winbar = "%!v:lua.get_oil_winbar()",
  --       },
  --     })
  --     vim.keymap.set('n', '[neotree]a', ':<C-u>Oil<CR>', { remap = true, silent = true })
  --     vim.keymap.set('n', '[neotree]d', ':<C-u>Oil .<CR>', { remap = true, silent = true })
  --   end
  -- },
  { "hrsh7th/nvim-insx",
    config = function()
      local helper = require('insx.helper')

      local PAIRS_MAP = {
        ['('] = ')',
        ['['] = ']',
        ['{'] = '}',
        ['<'] = '>',
      }

      ---@param option insx.recipe.fast_break.arguments.Option
      ---@return insx.RecipeSource
      local function trail_comma(option)
        return {
          ---@param ctx insx.Context
          action = function(ctx)
            -- Remove spaces.
            ctx.remove([[\s*\%#\s*]])

            -- Open side.
            local open_indent = helper.indent.get_current_indent()
            ctx.send('<CR>')
            ctx.send(helper.indent.adjust({
              current = helper.indent.get_current_indent(),
              expected = open_indent .. helper.indent.get_one_indent(),
            }))

            -- Close side.
            local row, col = ctx.row(), ctx.col()
            local close_pos = assert(helper.search.get_pair_close(option.open_pat, option.close_pat))
            ctx.move(close_pos[1], close_pos[2])
            ctx.send(',')
            -- ctx.send(helper.indent.adjust({
            --   current = helper.indent.get_current_indent(),
            --   expected = open_indent,
            -- }))
            ctx.move(row, col)

            -- Split behavior.
            local memo_row, memo_col = ctx.row(), ctx.col()
            local main_close_pos = helper.search.get_pair_close(option.open_pat, option.close_pat)
            while true do
              local comma_pos = ctx.search([[\%#.\{-},\s*\zs]])
              if not comma_pos or comma_pos[1] ~= ctx.row() then
                break
              end
              ctx.move(comma_pos[1], comma_pos[2])

              local inner = false
              for open, close in pairs(PAIRS_MAP) do
                local curr_close_pos = helper.search.get_pair_close(helper.regex.esc(open), helper.regex.esc(close))
                if main_close_pos and curr_close_pos and helper.position.lt(curr_close_pos, main_close_pos) then
                  inner = true
                  break
                end
              end

              if not inner then
                ctx.backspace([[\s*]])
                ctx.send('<CR>')
                ctx.send(helper.indent.adjust({
                  current = helper.indent.get_current_indent(),
                  expected = open_indent .. helper.indent.get_one_indent(),
                }))
                main_close_pos = helper.search.get_pair_close(option.open_pat, option.close_pat)
              end
            end
            ctx.backspace(helper.indent.get_one_indent())
            ctx.move(memo_row, memo_col)
          end,
          ---@param ctx insx.Context
          enabled = function(ctx)
            if not ctx.match(option.open_pat .. [[\s*\%#]]) then
              return false
            end
            local close_pos = helper.search.get_pair_close(option.open_pat, option.close_pat)
            if not close_pos or close_pos[1] ~= ctx.row() then
              return false
            end

            if ctx.filetype ~= 'go' then
              return false
            end
            return true
          end,
        }
      end
      require("insx").add('<CR>', trail_comma({
        open_pat = '(',
        close_pat = ')',
      }))

      require("insx.preset.standard").setup({})
    end
  },
  { "sindrets/diffview.nvim",
    config = function()
      require("diffview").setup()
    end
  },
  { "lambdalisue/vim-suda" },
  { "tokorom/vim-review" },
  -- { "coder/claudecode.nvim",
  --   dependencies = {
  --     "folke/snacks.nvim", -- Optional for enhanced terminal
  --   },
  --   config = true,
  --   keys = {
  --       { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "ClaudeCode" },
  --       { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
  --       { "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add file", ft = { "NvimTree", "neo-tree", "oil" }},
  --       { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
  --       { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
  --       { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
  --       { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
  --       -- Diff management
  --       { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
  --       { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  --   },
  -- },
  { "lambdalisue/nvim-aibo",
    config = function()
      require("aibo").setup({})
    end,
    keys = {
        { "<leader>ac", "<cmd>Aibo -opener=vsplit claude --mcp-config=" .. vim.env.HOME .. "/.claude/mcp.json<cr>", desc = "Aibo claude code" },
        { "<leader>aC", "<cmd>Aibo -opener=vsplit claude --continue --mcp-config=" .. vim.env.HOME .. "/.claude/mcp.json<cr>", desc = "Aibo claude code" },
        { "<leader>ar", "<cmd>Aibo -opener=vsplit claude --resume --mcp-config=" .. vim.env.HOME .. "/.claude/mcp.json<cr>", desc = "Aibo claude code" },
        { "<leader>as", "<cmd>AiboSend<cr>", mode = {"n", "v"}, desc = "Send to Aibo" },
    },
  },
  { "kitagry/gh-review.nvim",
    keys = {
      { "<leader>ghr", ":GhReview<CR>", desc = "Review GitHub Pull Request" },
    },
  },
  { "A7Lavinraj/fyler.nvim",
    dependencies = { "nvim-mini/mini.icons" },
    branch = "stable",
    config = function ()
      local fyler = require("fyler")
      fyler.setup({
        views = {
          finder = {
            mappings = {
              ["zc"] = "CollapseNode",
              ["zM"] = "CollapseAll",
            },
          },
        },
      })

      vim.keymap.set('n', '[neotree]a', function() fyler.toggle({  kind = "split_left_most"  }) end)
    end,
  },
})
