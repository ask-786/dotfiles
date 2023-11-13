require("catppuccin").setup({
    flavour = "macchiato",         -- latte, frappe, macchiato, mocha
    transparent_background = true, -- disables setting the background color.
    no_italic = false,             -- Force no italic
    no_bold = false,               -- Force no bold
    no_underline = false,          -- Force no underline
    dim_inactive = {
        enabled = false,           -- dims the background color of inactive window
        shade = "dark",
        percentage = 0.01,         -- percentage of the shade to apply to the inactive window
    },
    styles = {                     -- Handles the styles of general hi groups (see `:h highlight-args`):
        comments = { "italic" },   -- Change the style of comments
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
    },
    color_overrides = {},
    custom_highlights = {},
    integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = false,
        mini = {
            enabled = true,
            indentscope_color = "",
        },
    },
})

vim.cmd.colorscheme("catppuccin");
