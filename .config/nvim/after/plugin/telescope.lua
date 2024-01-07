local builtin = require('telescope.builtin')
local telescope = require("telescope");

vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<leader>pg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>pe', "<cmd>Telescope diagnostics<cr>", {})
vim.keymap.set('n', '<C-g>', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', function ()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)

telescope.setup {
    extensions = {
        ["ui-select"] = {
            require("telescope.themes").get_dropdown {
                -- even more opts
            }
        },
        fzf = {
            fuzzy = true,                   -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true,    -- override the file sorter
            case_mode = "smart_case",       -- or "ignore_case" or "respect_case" the default case_mode is "smart_case"
        }
    },
    defaults = {
        file_ignore_patterns = {
            "node_modules"
        }
    },
    pickers = {
        find_files = {
            hidden = true
        },
    }
}

telescope.load_extension("ui-select", "fzf")