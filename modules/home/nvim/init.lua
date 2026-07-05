-- Tab and indentation settings
vim.opt.expandtab = true      -- Use spaces instead of tabs
vim.opt.tabstop = 2           -- Tab width is 2 spaces
vim.opt.shiftwidth = 2        -- Indent width is 2 spaces
vim.opt.softtabstop = 2       -- Number of spaces inserted when pressing Tab

vim.o.signcolumn = 'yes'

vim.lsp.enable({ "nixd", "gopls" })

