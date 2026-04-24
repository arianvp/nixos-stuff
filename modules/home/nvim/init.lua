-- Tab and indentation settings
vim.opt.expandtab = true      -- Use spaces instead of tabs
vim.opt.tabstop = 2           -- Tab width is 2 spaces
vim.opt.shiftwidth = 2        -- Indent width is 2 spaces
vim.opt.softtabstop = 2       -- Number of spaces inserted when pressing Tab

vim.o.signcolumn = 'yes'

vim.lsp.config['nixd'] = {
  cmd = { 'nixd' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', 'default.nix' },
  settings = {
    nixd = {
      formatting = {
        command = { 'nixfmt' }
      }
    }
  },
  on_attach = function(client, bufnr)
    if client.supports_method('textDocument/formatting') then
      vim.api.nvim_buf_create_user_command(bufnr, 'Format', function()
        vim.lsp.buf.format({ async = false })
      end, { desc = 'Format buffer with LSP' })
    end
  end
}
vim.lsp.enable('nixd')

vim.lsp.config['gopls'] = {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.mod', 'go.work', '.git' },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
      gofumpt = true,
    },
  },
  on_attach = function(client, bufnr)
    if client.supports_method('textDocument/formatting') then
      vim.api.nvim_buf_create_user_command(bufnr, 'Format', function()
        vim.lsp.buf.format({ async = false })
      end, { desc = 'Format buffer with LSP' })
    end
  end
}
vim.lsp.enable('gopls')
