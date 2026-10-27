return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,          -- show hidden files
        hide_dotfiles = false,   -- don't hide dotfiles
        hide_gitignored = false, -- optional: also show gitignored files
      },
    },
  },
}
