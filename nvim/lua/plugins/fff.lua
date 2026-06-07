return {
	"dmtrKovalenko/fff.nvim",
	build = "cargo build --release",
	-- or if you are using nixos
	-- build = "nix run .#release",
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
	},
}
