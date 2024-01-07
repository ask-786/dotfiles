-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function (use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'
    use 'rstacruz/vim-closer'
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.4',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }
    use('nvim-tree/nvim-web-devicons')
    use({ "catppuccin/nvim", as = "catppuccin" });
    use('nvim-treesitter/nvim-treesitter', { run = ':TSUpdate' });
    use('nvim-treesitter/playground');
    use {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        requires = { { "nvim-lua/plenary.nvim" } }
    }
    use('tpope/vim-fugitive');
    use('tpope/vim-commentary');
    use('mbbill/undotree');
    use('jose-elias-alvarez/null-ls.nvim');
    use('nvim-telescope/telescope-ui-select.nvim');
    use({ 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' })
    use('christoomey/vim-tmux-navigator');
    use('lewis6991/gitsigns.nvim')
    use('j-hui/fidget.nvim');
    use('sindrets/diffview.nvim');
    use('folke/zen-mode.nvim');
    use {
        "windwp/nvim-autopairs",
        config = function () require("nvim-autopairs").setup {} end,
    }
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' }, -- Required
            {                      -- Optional
                'williamboman/mason.nvim',
                run = function ()
                    pcall(vim.cmd, 'MasonUpdate');
                end,
            },
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' }, -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
            { 'L3MON4D3/LuaSnip' }, -- Required
            { 'hrsh7th/cmp-path' },
            { 'hrsh7th/cmp-buffer' },
        }
    }
end)