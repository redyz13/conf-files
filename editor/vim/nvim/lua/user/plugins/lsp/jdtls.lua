return {
  "mfussenegger/nvim-jdtls",
  ft = "java",
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        local jdtls = require("jdtls")
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        local root_dir = require("jdtls.setup").find_root({ "pom.xml", "mvnw", "gradlew", ".git" }) or vim.fn.getcwd()

        local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")
        local mason_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
        local cmd = mason_path .. "/bin/jdtls"

        local config = {
          cmd = { cmd, "-data", workspace_dir },
          root_dir = root_dir,
          capabilities = capabilities,
          settings = {
            java = {
              eclipse = { downloadSources = true },
              configuration = { updateBuildConfiguration = "interactive" },
              maven = { downloadSources = true },
              implementationsCodeLens = { enabled = true },
              referencesCodeLens = { enabled = true },
              references = { includeDecompiledSources = true },
              inlayHints = { parameterNames = { enabled = "all" } },
            },
          },
          flags = { allow_incremental_sync = true },
        }

        jdtls.start_or_attach(config)

        local opts = { noremap = true, silent = true, buffer = true }
        vim.keymap.set("n", "<leader>oi", jdtls.organize_imports, opts)
        vim.keymap.set("n", "crv", jdtls.extract_variable, opts)
        vim.keymap.set("v", "crv", function() jdtls.extract_variable(true) end, opts)
        vim.keymap.set("n", "crc", jdtls.extract_constant, opts)
        vim.keymap.set("v", "crc", function() jdtls.extract_constant(true) end, opts)
        vim.keymap.set("v", "crm", function() jdtls.extract_method(true) end, opts)
      end,
    })
  end,
}


