local lsp_zero = require('lsp-zero').preset({})
local lsp_config = require('lspconfig');
local null_ls = require('null-ls');

lsp_zero.on_attach(function(client, bufnr)
    lsp_zero.default_keymaps({ buffer = bufnr })
end)

lsp_zero.ensure_installed({ 'tsserver', 'eslint', 'lua_ls', 'rust_analyzer' })

local on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set('n', "gd", function() vim.lsp.buf.definition() end, opts);
    vim.keymap.set('n', "K", function() vim.lsp.buf.hover() end, opts);
    vim.keymap.set('n', "<leader>e", function() vim.diagnostic.open_float() end, opts);
    vim.keymap.set('n', "[d", function() vim.diagnostic.goto_next() end, opts);
    vim.keymap.set('n', "]d", function() vim.diagnostic.goto_prev() end, opts);
    vim.keymap.set('n', "<leader>ca", function() vim.lsp.buf.code_action() end, opts);
    vim.keymap.set('n', "<leader>gr", function() vim.lsp.buf.references() end, opts);
    vim.keymap.set('n', "<leader>rn", function() vim.lsp.buf.rename() end, opts);
    vim.keymap.set('i', "<C-a>", function() vim.lsp.buf.signature_help() end, opts);
    vim.keymap.set("n", "<leader>dg", function() vim.diagnostic.setqflist() end, opts);
end

lsp_zero.on_attach(on_attach);

lsp_zero.format_mapping('<leader>ff', {
    format_opts = {
        async = false,
        timeout_ms = 10000,
    },
    servers = {
        ['lua_ls'] = { 'lua' },
        ['rust_analyzer'] = { 'rust' },
        ['null-ls'] = { 'javascript', 'typescript' },
        ['dartls'] = { 'dart' },
    }
})


lsp_config['dartls'].setup({
    on_attach = on_attach,
    root_dir = lsp_config.util.root_pattern("pubspec.yaml"),
    init_options = {
        closingLabels = true,
    },
    settings = {
        dart = {
            analysisExcludedFolders = {
                vim.fn.expand("$HOME/AppData/Local/Pub/Cache"),
                vim.fn.expand("$HOME/.pub-cache/"),
                vim.fn.expand("$HOME/tools/flutter/"),
            },
            updateImportsOnRename = true,
            completeFunctionCalls = true,
            showTodos = true,
        }
    }
})

lsp_zero.setup()

local cmp = require('cmp');

cmp.setup({
    mapping = {
        -- `Enter` key to confirm completion
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<C-Space>'] = cmp.mapping.complete(),
    }
})

null_ls.setup({
    on_attach = on_attach,
    sources = {
        null_ls.builtins.formatting.prettier,
    }
})
