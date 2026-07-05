return {
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
