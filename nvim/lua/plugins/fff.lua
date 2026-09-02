return {
	"dmtrKovalenko/fff",
	build = function()
		-- downloads a prebuilt binary or falls back to cargo build
		require("fff.download").download_or_build_binary()
	end,
	-- or if you are using nixos
	-- build = "nix run .#release",
	lazy = false, -- the plugin lazy-initialises itself
	opts = {},
	keys = {
		{
			"<leader>ff", -- try it if you didn't it is a banger keybinding for a picker
			function()
				require("fff").find_files()
			end,
			desc = "Open file picker",
		},
		{
			"<leader>fg",
			function()
				require("fff").find_in_git_root()
			end,
			desc = "Open git tracked file picker",
		},
		{
			"<leader>fs",
			function()
				require("fff").live_grep()
			end,
			desc = "Live grep",
		},
	},
}
