-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.keymap.set("n", "<leader>b", function()
  local line = vim.fn.getline(".")
  vim.fn.setreg("0", vim.fn.fnamemodify(line, ":t"))
end, { noremap = true, silent = true })
