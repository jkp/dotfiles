-- Custom keymaps
vim.keymap.set({ 'n', 'v' }, ';', ':', { desc = 'Enter command mode' })
vim.keymap.set('n', ':', ';', { desc = 'Repeat last f/t motion' })
vim.keymap.set('i', 'tn', '<Esc>', { desc = 'Exit insert mode' })

-- Colemak-DH: Swap j/k for spatial consistency
-- On Colemak, J is top row, K is bottom row, so j should go up, k should go down
local modes = { 'n', 'v', 'o', 's' } -- normal, visual, operator-pending, select
vim.keymap.set(modes, 'j', 'k', { noremap = true, desc = 'Move up' })
vim.keymap.set(modes, 'k', 'j', { noremap = true, desc = 'Move down' })

-- Swap gj/gk for wrapped line movement
vim.keymap.set(modes, 'gj', 'gk', { noremap = true, desc = 'Move up (wrapped)' })
vim.keymap.set(modes, 'gk', 'gj', { noremap = true, desc = 'Move down (wrapped)' })

-- Swap window navigation
vim.keymap.set('n', '<C-w>j', '<C-w>k', { noremap = true, desc = 'Window up' })
vim.keymap.set('n', '<C-w>k', '<C-w>j', { noremap = true, desc = 'Window down' })
