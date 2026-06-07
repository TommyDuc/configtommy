require("coerce").setup({
	keymap_registry = require("coerce.keymap").keymap_registry(),
	-- The notification function used during error conditions.
	notify = function(...) return vim.notify(...) end,
	default_mode_keymap_prefixes = {
		normal_mode = "<leader>cr",
		motion_mode = "<leader>gcr",
		visual_mode = "<leader>gcr",
	},
	-- Set any field to false to disable that mode.
	default_mode_mask = {
		normal_mode = true,
		motion_mode = true,
		visual_mode = true,
	},
	-- -- If you don’t like the default cases and modes, you can override them.
	-- cases = require"coerce".default_cases,
	-- modes = require"coerce".get_default_modes(default_mode_mask, default_mode_keymap_prefixes),
})

-- Quick start:
-- Put the cursor inside a keyword.
-- Press <leader>crX, where X stands for your desired case. Which key, if present, will show you hints.
--
-- Built-in cases
-- Case 	Key
-- camelCase 	c
-- dot.case 	d
-- kebab-case 	k
-- n12e 	n
-- PascalCase 	p
-- snake_case 	s
-- UPPER_CASE 	u
-- path/case 	/
-- space case 	<space>
-- Built-in modes
-- Vim mode 	Keymap prefix 	Selector 	Transformer
-- Normal 	cr 	current word 	LSP rename/local
-- Normal 	gcr 	motion selection 	local
-- Visual 	gcr 	visual selection 	local
