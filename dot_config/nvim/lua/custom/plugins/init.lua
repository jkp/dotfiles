-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'ThePrimeagen/vim-be-good',
    cmd = 'VimBeGood',
  },
  {
    'jvgrootveld/telescope-zoxide',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      { '<leader>cd', '<cmd>Telescope zoxide list<cr>', desc = 'Zoxide' },
    },
    config = function()
      require('telescope').load_extension 'zoxide'
    end,
  },
}
