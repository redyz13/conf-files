local mp = require 'mp'
local msg = require 'mp.msg'

local history = {}
local max_lines = 10

local function format_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

mp.observe_property("sub-text", "string", function(_, text)
    if text and text ~= "" then
        local time = mp.get_property_number("time-pos", 0)
        table.insert(history, {
            text = text,
            time = format_time(time)
        })

        if #history > max_lines then
            table.remove(history, 1)
        end
    end
end)

local function show_history()
    local output = ""

    for i = 1, #history do
        local entry = history[i]
        output = output .. "[" .. entry.time .. "] " .. entry.text .. "\n"
    end

    if output == "" then
        output = "No subtitles yet"
    end

    mp.osd_message(output, 5)
end

mp.add_key_binding("h", "show-sub-history", show_history)

