local M = {}
function M.setupTreesitter()
  -- require 'nvim-treesitter'.define_modules {
  --   goaddtags = {
  --     attach = function(bufnr, lang)
  --       print(bufnr)
  --     end,
  --     detach = function(bufnr)
  --     end,
  --     is_supported = function(lang)
  --       print(lang)
  --       return lang == 'go'
  --     end,
  --   }
  -- }

  require 'nvim-treesitter.configs'.setup {
    ensure_installed = "all",
    ignore_install = { "haskell" },
    highlight = {
      enable = true,
    },
    playground = {
      enable = true,
      disable = {},
      updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
      persist_queries = false -- Whether the query persists across vim sessions
    },
    goaddtags = {
      enable = true,
      keymap = {
        goaddtags = "gt"
      },
    },
  }
end
return M
