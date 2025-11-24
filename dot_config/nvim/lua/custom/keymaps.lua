-- Custom keymaps
vim.keymap.set({ 'n', 'v' }, ';', ':', { desc = 'Enter command mode' })
vim.keymap.set('n', ':', ';', { desc = 'Repeat last f/t motion' })
vim.keymap.set('i', 'tn', '<Esc>', { desc = 'Exit insert mode' })

-- Minimal Colemak navigation
-- vim.keymap.set({ 'n', 'v' }, 'n', 'j', { desc = 'Down' })
-- vim.keymap.set({ 'n', 'v' }, 'e', 'k', { desc = 'Up' })
-- vim.keymap.set({ 'n', 'v' }, 'i', 'l', { desc = 'Right' })
-- vim.keymap.set({ 'n', 'v' }, 'j', 'e', { desc = 'End of word' })
--
-- -- Put insert on k
-- vim.keymap.set('n', 'm', 'i', { desc = 'Insert' })
-- vim.keymap.set('n', 'M', 'I', { desc = 'Insert at line start' })
--
-- -- Remap conflicts we use
-- vim.keymap.set({ 'n', 'v' }, 'l', 'e', { desc = 'End of word' })
-- vim.keymap.set({ 'n', 'v' }, 'k', 'n', { desc = 'Next search result' })
-- vim.keymap.set({ 'n', 'v' }, 'K', 'N', { desc = 'Previous search result' })
