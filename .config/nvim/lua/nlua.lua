local custom_nvim_lspconfig_attach = function(...) end

require('nlua.lsp.nvim').setup(require('nvim_lsp'), {
  on_attach = custom_nvim_lspconfig_attach,
})
