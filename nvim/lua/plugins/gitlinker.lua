return {
	"linrongbin16/gitlinker.nvim",
	cmd = "GitLink",
	opts = {},
	keys = {
		{ "<leader>gy", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Yank git link on remote" },
		{ "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Open git link on remote" },
		{ "<leader>gb", "<cmd>GitLink blame<cr>", mode = {"n", "v"}, desc="Yank git blame on remote" },
		{ "<leader>gB", "<cmd>GitLink! blame<cr>", mode = {"n", "v"}, desc="Open git blame on remote" },
	},
}
