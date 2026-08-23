return {
  "lukas-reineke/indent-blankline.nvim",
  name = "indent-line",
  main = "ibl",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    indent = {
      -- char = "│",
      char = "▏",
      -- char = "▎",
      highlight = "Whitespace",
      smart_indent_cap = false,
    },

    whitespace = {
      remove_blankline_trail = true,
    },

    scope = {
      enabled = true,

      show_start = true,
      show_end = false,
      show_exact_scope = false,

      highlight = "Label",

      include = {
        node_type = {
          bash = {
            "if_statement",
            "while_statement",
            "for_statement",
          },

          c = {
            "return_statement",
          },

          cpp = {
            "return_statement",
            "for_range_loop",
            "try_statement",
          },

          java = {
            "class_declaration",
            "class_body",
            "method_invocation",
            "method_reference",
            "return_statement",
            "while_statement",
          },

          lua = {
            "block",
            "return_statement",
            "table_constructor",
            "arguments",
          },

          python = {
            "block",
            "if_statement",
            "else_clause",
            "for_statement",
            "while_statement",
            "try_statement",
            "return_statement",
            "import_statement",
          },
        },
      },

      exclude = {
        language = {
          "query",
        },

        node_type = {
          c = {
            "compound_statement",
          },

          cpp = {
            "compound_statement",
            "template_declaration",
            "body",
            "lambda_expression",
            "requires_expression",
          },

          java = {
            "lambda_expression",
            "enhanced_for_statement",
            "constructor_declaration",
          },

          lua = {
            "do_statement",
            "repeat_statement",
          },

          python = {
            "dictionary_comprehension",
            "list_comprehension",
            "set_comprehension",
          },
        },
      },
    },

    exclude = {
      buftypes = {
        "terminal",
        "nofile",
        "quickfix",
        "prompt",
      },

      filetypes = {
        "",
        "help",
        "man",
        "lspinfo",
        "checkhealth",
        "gitcommit",
        "TelescopePrompt",
        "TelescopeResults",
        "startify",
        "dashboard",
        "packer",
        "neogitstatus",
        "NvimTree",
        "Trouble",
        "markdown",
      },
    },
  },
}
