local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local action_state = require("telescope.actions.state")

local M = {}

local defaults = {
	mappings = {
		models = "<leader>rm",
		controllers = "<leader>rc",
		views = "<leader>rv",
		libs = "<leader>rl",
		migrations = "<leader>ri",
		jobs = "<leader>rj",
		specs = "<leader>rt",
	},
	targets = {
		models = "app/models",
		controllers = "app/controllers",
		views = "app/views",
		libs = "lib",
		migrations = "db/migrate",
		jobs = "app/jobs",
		specs = "spec",
	},
}

local function path_to_display_name(file, target_path)
	return file:sub(#target_path + 2)
end

local displayer = entry_display.create({
	separator = " ",
	items = {
		{ width = 45 },
		{ remaining = true },
	},
})

local make_display = function(entry)
	local display_name = vim.fn.fnamemodify(entry.ordinal, ":t")
	local path = vim.fn.fnamemodify(entry.ordinal, ":h")
	if path == "." then
		return displayer({
			display_name,
			{ "", "Comment" },
		})
	else
		return displayer({
			display_name,
			{ path, "Comment" },
		})
	end
end

local function get_prompt_title(target)
	local titles = {
		models = "Rails Models",
		controllers = "Rails Controllers",
		views = "Rails Views",
		libs = "Rails Libs",
		migrations = "Rails Migrations",
		jobs = "Rails Jobs",
		specs = "Rails Specs",
	}
	return titles[target] or string.format("Rails %s", target:gsub("^%l", string.upper))
end

local find_rails = function(opts, target, target_path)
	pickers
		.new(opts, {
			prompt_title = string.format("< %s >", get_prompt_title(target)),
			finder = finders.new_oneshot_job({
				"find",
				target_path,
				"-type",
				"f",
			}, {
				entry_maker = function(file)
					local path_without_prefix = path_to_display_name(file, target_path)
					return {
						value = file,
						display = make_display,
						ordinal = path_without_prefix,
						path = file,
					}
				end,
			}),
			sorter = conf.file_sorter(opts),
			previewer = conf.file_previewer(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.cmd("edit " .. selection.path)
				end)
				return true
			end,
		})
		:find()
end

local function setup_keymaps(user_mappings)
	local mappings = vim.tbl_deep_extend("force", defaults.mappings, user_mappings or {})
	for key, mapping in pairs(mappings) do
		vim.api.nvim_set_keymap(
			"n",
			mapping,
			string.format([[<cmd>lua require('telescope').extensions.rails.%s()<CR>]], key),
			{ noremap = true, silent = true }
		)
	end
end

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", defaults, opts)
	setup_keymaps(M.config.mappings)
end

for key, path in pairs(defaults.targets) do
	M[key] = function(opts)
		opts = opts or {}
		opts.cwd = opts.cwd or vim.fn.getcwd() .. "/" .. path
		find_rails(opts, key, path)
	end
end

return require("telescope").register_extension({
	setup = M.setup,
	exports = M,
})
