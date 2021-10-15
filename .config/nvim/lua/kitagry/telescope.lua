local actions = require('telescope.actions')
require('telescope').setup{
  defaults = {
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
  },
}
