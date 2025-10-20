return {
    "williamboman/mason.nvim",
    name = "mason",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "jayp0521/mason-null-ls.nvim",
    },
    config = function()
      local mason = require("mason")
      local mason_lspconfig = require("mason-lspconfig")
      local mason_null_ls = require("mason-null-ls")

      mason.setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })

      mason_lspconfig.setup({
        -- Servers
        ensure_installed = {
          "lua_ls",
          "clangd",
          "pyright",
          "jdtls",
        },
        automatic_installation = true,
        automatic_enable = false,
      })

      mason_null_ls.setup({
        -- Formatters & linters
        ensure_installed = {
          "stylua",
          "black",
          "ruff",
        },
        automatic_installation = true,
        automatic_enable = false,
      })
    end
}
