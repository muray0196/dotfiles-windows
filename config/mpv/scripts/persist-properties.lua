local utils = require "mp.utils"
local msg = require "mp.msg"
local opts = { properties = "volume,sub-scale" }
(require 'mp.options').read_options(opts, "persist_properties")

local CONFIG_ROOT = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/'
if not utils.file_info(CONFIG_ROOT) then
    local mpv_conf_path = mp.find_config_file and mp.find_config_file("scripts")
    if mpv_conf_path then
        local mpv_conf_dir = utils.split_path(mpv_conf_path)
        CONFIG_ROOT = mpv_conf_dir
    end
end
local PCONFIG = CONFIG_ROOT..'persistent_config.json'

local function split(input)
    local ret = {}
    for str in string.gmatch(input or "", "([^,]+)") do
        local s = (str:gsub("^%s*(.-)%s*$", "%1"))
        if s ~= "" then table.insert(ret, s) end
    end
    return ret
end
local persisted_properties = split(opts.properties)

local isInitialized = false
local properties = {}

local function load_config(file)
    local f = io.open(file, "r")
    if not f then return {} end
    local jsonString = f:read("*a")
    f:close()
    if not jsonString or jsonString == "" then return {} end
    return utils.parse_json(jsonString) or {}
end

local function save_config(path, props)
    local serialized = utils.format_json(props)
    local f, err = io.open(path, "wb")
    if not f then
        msg.error(("open failed: %s (%s)"):format(path, err or ""))
        return false
    end
    f:write(serialized)
    f:close()
    return true
end

local save_timer = nil
local got_unsaved_changed = false

local function onInitialLoad()
    properties = load_config(PCONFIG)

    for _, name in ipairs(persisted_properties) do
        local value = properties[name]
        if value ~= nil then
            mp.set_property_native(name, value)
        end
    end

    for _, name in ipairs(persisted_properties) do
        mp.observe_property(name, "native", function(prop, value)
            if not isInitialized then return end
            if properties[prop] == value then return end
            properties[prop] = value
            got_unsaved_changed = true

            if save_timer then
                save_timer:kill()
                save_timer = nil
            end
            save_timer = mp.add_timeout(5, function()
                local ok = save_config(PCONFIG, properties)
                if ok then
                    got_unsaved_changed = false
                    save_timer = nil
                end
            end)
        end)
    end

    isInitialized = true
end

onInitialLoad()

mp.register_event("shutdown", function()
    if got_unsaved_changed or save_timer then
        save_config(PCONFIG, properties)
    end
end)
