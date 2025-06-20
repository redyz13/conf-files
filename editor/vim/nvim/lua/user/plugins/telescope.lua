return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-file-browser.nvim',
  },
  name = "telescope",
  config = function()
    vim.keymap.set("n", "<leader>ff","<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>")
    vim.keymap.set("n", "<leader>fg","<cmd>lua require('telescope.builtin').git_files(require('telescope.themes').get_dropdown{previewer = false})<cr>")
    vim.keymap.set("n", "<leader>fF","<cmd>lua require('telescope.builtin').find_files()<cr>")
    vim.keymap.set("n", "<leader>fB","<cmd>lua require('telescope.builtin').buffers()<cr>")
    vim.keymap.set("n", "<leader>fh","<cmd>lua require('telescope.builtin').help_tags()<cr>")
    vim.keymap.set("n", "<leader>fO","<cmd>lua require('telescope.builtin').oldfiles()<cr>")
    vim.keymap.set("n", "<leader>fo","<cmd>lua require('telescope.builtin').oldfiles(require('telescope.themes').get_dropdown{previewer = false})<cr>")
    vim.keymap.set("n", "<leader>fs","<cmd>lua require('telescope.builtin').grep_string()<cr>")
    vim.keymap.set("n", "<leader>fb","<cmd>lua require('telescope').extensions.file_browser.file_browser(require('telescope.themes').get_dropdown{previewer = false})<cr>")
    vim.keymap.set("n", "<leader>b","<cmd>lua require('telescope.builtin').buffers(require('telescope.themes').get_dropdown{previewer = false})<cr>")
    vim.keymap.set("n", "<leader>F","<cmd>Telescope live_grep theme=ivy<cr>")
    vim.keymap.set("n", "<leader>P","<cmd>lua require('telescope').extensions.projects.projects()<cr>")

    local actions = require("telescope.actions")

    require("telescope").setup({

      defaults = {
        prompt_prefix = " ",
        -- selection_caret = " ",
        path_display = { "smart" },

        mappings = {
          i = {
            ["<C-n>"] = actions.cycle_history_next,
            ["<C-p>"] = actions.cycle_history_prev,

            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,

            ["<C-c>"] = actions.close,

            ["<Down>"] = actions.move_selection_next,
            ["<Up>"] = actions.move_selection_previous,

            ["<CR>"] = actions.select_default,
            ["<C-x>"] = actions.select_horizontal,
            ["<C-v>"] = actions.select_vertical,
            ["<C-t>"] = actions.select_tab,

            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,

            ["<PageUp>"] = actions.results_scrolling_up,
            ["<PageDown>"] = actions.results_scrolling_down,

            ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
            ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
            ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            ["<C-l>"] = actions.complete_tag,
            ["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
          },

          n = {
            ["<esc>"] = actions.close,
            ["<CR>"] = actions.select_default,
            ["<C-x>"] = actions.select_horizontal,
            ["<C-v>"] = actions.select_vertical,
            ["<C-t>"] = actions.select_tab,

            ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
            ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
            ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

            ["j"] = actions.move_selection_next,
            ["k"] = actions.move_selection_previous,
            ["H"] = actions.move_to_top,
            ["M"] = actions.move_to_middle,
            ["L"] = actions.move_to_bottom,

            ["<Down>"] = actions.move_selection_next,
            ["<Up>"] = actions.move_selection_previous,
            ["gg"] = actions.move_to_top,
            ["G"] = actions.move_to_bottom,

            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,

            ["<PageUp>"] = actions.results_scrolling_up,
            ["<PageDown>"] = actions.results_scrolling_down,

            ["?"] = actions.which_key,
          },
        },
      },
      pickers = {
        -- Default configuration for builtin pickers goes here:
        -- picker_name = {
        --   picker_config_key = value,
        --   ...
        -- }
        -- Now the picker_config_key will be applied every time you call this
        -- builtin picker
      },
      extensions = {
        -- Your extension configuration goes here:
        file_browser = {
          theme = "ivy",
          hijack_netrw = true,
        }
        -- please take a look at the readme of the extension you want to configure
      },

      require("telescope").load_extension "file_browser"

    })
  end
}
