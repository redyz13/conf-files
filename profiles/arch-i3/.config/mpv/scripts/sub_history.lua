local mp = require 'mp'
local msg = require 'mp.msg'

local history = {}
local max_lines = 10
local last_text = nil

local function format_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

mp.observe_property("sub-text", "string", function(_, text)
    if not text or text == "" then
        return
    end

    if text == last_text then
        return
    end
    last_text = text

    local time = mp.get_property_number("time-pos", 0)

    table.insert(history, {
        text = text,
        time = format_time(time)
    })

    if #history > max_lines then
        table.remove(history, 1)
    end
end)

local function show_history()
    if #history == 0 then
        mp.osd_message("No subtitles yet", 5)
        return
    end

    local lines = {}
    for i = 1, #history do
        local entry = history[i]
        lines[#lines + 1] = string.format("[%s] %s", entry.time, entry.text)
    end

    mp.osd_message(table.concat(lines, "\n"), 5)
end

mp.add_key_binding("h", "show-sub-history", show_history)

