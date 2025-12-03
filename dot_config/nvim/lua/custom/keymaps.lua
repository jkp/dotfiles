-- Custom keymaps
vim.keymap.set({ 'n', 'v' }, ';', ':', { desc = 'Enter command mode' })
vim.keymap.set('n', ':', ';', { desc = 'Repeat last f/t motion' })
vim.keymap.set('i', 'tn', '<Esc>', { desc = 'Exit insert mode' })

-- Arrow keys to hjkl
local modes = { 'n', 'v', 'o', 's' }
vim.keymap.set(modes, '<Left>', 'h', { noremap = true })
vim.keymap.set(modes, '<Down>', 'j', { noremap = true })
vim.keymap.set(modes, '<Up>', 'k', { noremap = true })
vim.keymap.set(modes, '<Right>', 'l', { noremap = true })
