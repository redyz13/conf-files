return {
  'akinsho/bufferline.nvim',
  -- version = "*",
  dependencies = 'nvim-tree/nvim-web-devicons',
  after = "catppuccin",
  name = 'bufferline',
  config = function()
    -- local mocha = require("catppuccin.palettes").get_palette "mocha"

    require("bufferline").setup{
      options = {
        color_icons = true,
        numbers = "none", -- | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
        close_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
        right_mouse_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
        left_mouse_command = "buffer %d", -- can be a string | function, see "Mouse actions"
        middle_mouse_command = nil, -- can be a string | function, see "Mouse actions"
        -- NOTE: this plugin is designed with this icon in mind,
        -- and so changing this is NOT recommended, this is intended
        -- as an escape hatch for people who cannot bear it for whatever reason
        indicator_icon = "▎",
        buffer_close_icon = "󰅖",
        -- buffer_close_icon = '',
        modified_icon = "●",
        close_icon = "",
        -- close_icon = '',
        left_trunc_marker = "",
        right_trunc_marker = "",
        --- name_formatter can be used to change the buffer's label in the bufferline.
        --- Please note some names can/will break the
        --- bufferline so use this at your discretion knowing that it has
        --- some limitations that will *NOT* be fixed.
        -- name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
        --   -- remove extension from markdown files for example
        --   if buf.name:match('%.md') then
        --     return vim.fn.fnamemodify(buf.name, ':t:r')
        --   end
        -- end,
        max_name_length = 30,
        max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
        tab_size = 21,
        diagnostics = false, -- | "nvim_lsp" | "coc",
        diagnostics_update_in_insert = false,
        -- diagnostics_indicator = function(count, level, diagnostics_dict, context)
        --   return "("..count..")"
        -- end,
        -- NOTE: this will be called a lot so don't do any heavy processing here
        -- custom_filter = function(buf_number)
        --   -- filter out filetypes you don't want to see
        --   if vim.bo[buf_number].filetype ~= "<i-dont-want-to-see-this>" then
        --     return true
        --   end
        --   -- filter out by buffer name
        --   if vim.fn.bufname(buf_number) ~= "<buffer-name-I-dont-want>" then
        --     return true
        --   end
        --   -- filter out based on arbitrary rules
        --   -- e.g. filter out vim wiki buffer from tabline in your work repo
        --   if vim.fn.getcwd() == "<work-repo>" and vim.bo[buf_number].filetype ~= "wiki" then
        --     return true
        --   end
        -- end,

        -- TODO vim . error
        offsets = { {
          filetype = "NvimTree", text = "File Browser", padding = 0,
          highlight = "Directory",
          separator = true, -- use a "true" to enable the default, or set your own character
        }},

        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        show_tab_indicators = true,
        persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
        -- can also be a table containing 2 custom separators
        -- [focused and unfocused]. eg: { '|', '|' }
        separator_style = "thin", -- | "thick" | "thin" | { 'any', 'any' },
        enforce_regular_tabs = true,
        always_show_bufferline = false,
        -- sort_by = 'id' | 'extension' | 'relative_directory' | 'directory' | 'tabs' | function(buffer_a, buffer_b)
        --   -- add custom logic
        --   return buffer_a.modified > buffer_b.modified
        -- end
      },
      -- Uncomment for catppuccin theme
      -- highlights = require("catppuccin.groups.integrations.bufferline").get {
      --   styles = { "italic", "bold" },
      --   custom = {
      --     mocha = {
      --       fill = { bg = '#1e1e2e', },
      --       close_button = { bg = '#1e1e2e', },
      --       background = { bg = '#1e1e2e', },
      --       close_button_visible = { bg = '#1e1e2e', },
      --       separator = { bg = '#1e1e2e', fg = '#1e1e2e' },
      --       separator_selected = { bg = '#1e1e2e', fg = '#1e1e2e', },
      --       buffer_visible = { bg = '#1e1e2e', fg = '#6c7086', },
      --       indicator_visible = { bg = '#1e1e2e', fg = '#1e1e2e', },
      --       modified = { bg = '#1e1e2e', },
      --       modified_visible = { bg = '#1e1e2e', },
      --       modified_selected = { bg = '#1e1e2e', },
      --       trunc_marker = { bg = '#1e1e2e', },
      --     },
      --   },
      -- },
      highlights = {
    --     fill = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --       -- bg = '#1e1e2e', -- Change based on theme,
    --       bg = '#161622'
    --     },
    --
    --     background = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --
    --     buffer_selected = {
    --       guifg = {attribute='fg',highlight='TabLine'},
    --       guibg = {attribute='bg',highlight='TabLine'},
    --       -- bg = '#000000'
    --     },
    --     buffer_visible = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --
    --     close_button = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --     close_button_visible = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --     -- close_button_selected = {
    --     --   guifg = {attribute='fg',highlight='TabLineSel'},
    --     --   guibg ={attribute='bg',highlight='TabLineSel'}
    --     -- },
    --
    --     tab_selected = {
    --       guifg = { attribute = "fg", highlight = "Normal" },
    --       guibg = { attribute = "bg", highlight = "Normal" },
    --     },
    --     tab = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --     tab_close = {
    --       -- guifg = {attribute='fg',highlight='LspDiagnosticsDefaultError'},
    --       guifg = { attribute = "fg", highlight = "TabLineSel" },
    --       guibg = { attribute = "bg", highlight = "Normal" },
    --     },
    --
    --     duplicate_selected = {
    --       guifg = { attribute = "fg", highlight = "TabLineSel" },
    --       guibg = { attribute = "bg", highlight = "TabLineSel" },
    --       gui = "italic",
    --     },
    --     duplicate_visible = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --       gui = "italic",
    --     },
    --     duplicate = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --       gui = "italic",
    --     },
    --
    --     modified = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --     modified_selected = {
    --       guifg = { attribute = "fg", highlight = "Normal" },
    --       guibg = { attribute = "bg", highlight = "Normal" },
    --     },
    --     modified_visible = {
    --       guifg = { attribute = "fg", highlight = "TabLine" },
    --       guibg = { attribute = "bg", highlight = "TabLine" },
    --     },
    --
        separator = {
          guifg = { attribute = "bg", highlight = "TabLine" },
          guibg = { attribute = "bg", highlight = "TabLine" },
          fg = '#000000', -- Change based on theme,
        },
    --     separator_selected = {
    --       guifg = { attribute = "bg", highlight = "Normal" },
    --       guibg = { attribute = "bg", highlight = "Normal" },
    --       fg = '#1e1e2e', -- Change based on theme,
    --     },
    --     -- separator_visible = {
    --     --   guifg = {attribute='bg',highlight='TabLine'},
    --     --   guibg = {attribute='bg',highlight='TabLine'}
    --     --   },
    --
    --     indicator_selected = {
    --       guifg = { attribute = "fg", highlight = "LspDiagnosticsDefaultHint" },
    --       guibg = { attribute = "bg", highlight = "Normal" },
    --     },
      },
    }
  end
}
