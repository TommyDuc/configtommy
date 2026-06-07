local hop = require('hop')
local directions = require('hop.hint').HintDirection

hop.setup {
	-- The priority of keys used to navigate. Should minimize wrist movement.
	keys = 'nuieofpvxrqdgablyhtcksz',
	jump_on_sole_occurrence = false,
	uppercase_labels = false,
	multi_windows = true,
}

vim.keymap.set('', '<leader>hf', function()
	hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true })
end, { remap = true })

vim.keymap.set('', '<leader>hF', function()
	hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true })
end, { remap = true })

vim.keymap.set('', '<leader>ht', function()
	hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })
end, { remap = true })

vim.keymap.set('', '<leader>hT', function()
	hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })
end, { remap = true })

vim.keymap.set('', '<leader>hw', ':HopWord<CR>', { remap = true })

vim.keymap.set('', '<leader>hs', ':HopPattern<CR>', { remap = true })

vim.keymap.set('', '<leader>hl', ':HopLineStart<CR>', { remap = true })

vim.keymap.set('', '<leader>hn', ':HopNodes<CR>', { remap = true })

vim.keymap.set('', '<leader>h1', ':HopChar1<CR>', { remap = true })

vim.keymap.set('', '<leader>h2', ':HopChar2<CR>', { remap = true })
