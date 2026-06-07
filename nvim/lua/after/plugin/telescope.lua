local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
-- vim.keymap.set('n', '<leader>fg', builtin.git_files, {})
vim.keymap.set('n', '<leader>fl',
	function()
		builtin.live_grep({prompt_title = 'Live Grep', grep_open_files = true})
	end
)
vim.keymap.set('n', '<leader>fs',
	function()
		builtin.grep_string({ search=vim.fn.input("Grep: ") })
	end
)
