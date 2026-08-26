return {
  "neovim/nvim-lspconfig",
  name = "nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true }
  },
  config = function()
    local keymap = vim.keymap
    local opts = { noremap = true, silent = true, buffer = true }

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
      callback = function(args)
        opts.buffer = args.buf

        keymap.set("n", "gf", "<cmd>Lspsaga finder<CR>", opts) -- show definition, references
        keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration
        keymap.set("n", "gd", "<cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
        keymap.set("n", "gi", vim.lsp.buf.implementation, opts) -- go to implementation
        keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
        keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
        keymap.set("n", "<leader>D", "<cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show diagnostics for line
        -- keymap.set("n", "<leader>d", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts) -- show diagnostics for cursor
        keymap.set("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
        keymap.set("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
        keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
        keymap.set("n", "<leader>o", "<cmd>LSoutlineToggle<CR>", opts) -- see outline on right hand side

        -- Telescope
        keymap.set("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
        keymap.set("n", "<leader>ft", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions
        -- keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show diagnostics for file
      end,
    })

    vim.lsp.enable("pyright", {
      capabilities = capabilities,
    })

    vim.lsp.enable("clangd", {
      capabilities = capabilities,
    })

    vim.lsp.enable("lua_ls", {
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = {
              [vim.fn.expand("$VIMRUNTIME/lua")] = true,
              [vim.fn.stdpath("config") .. "/lua"] = true,
            }
          }
        }
      }
    })

    -- Old hint = "ﴞ"
    local signs = { Error = " ", Warn = " ", Hint = "󰵚", Info = " " }

    vim.diagnostic.config({
      signs = {
        text = {
          ERROR = signs.Error,
          WARN = signs.Warn,
          INFO = signs.Info,
          HINT = signs.Hint,
        },
      },
    })
  end,
}

