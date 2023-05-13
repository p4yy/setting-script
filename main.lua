
-- setting script rotation all-premium file
-- discord.gg/payy

CALL = false

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function toboolean(str)
    local bool = false
    if str == "true" then
        bool = true
    end
    return bool
end

local function input_user(text,s)
    if s == nil then
        s = "str"
    end
    io.write(text)
    local a = io.read()
    while true do
        if s == "int" then
            local b = tonumber(a)
            if type(b) == "number" then
                break
            else
                io.write(text)
                a = io.read()
            end
        elseif s == true then
            if a == "true" or a == "false" then
                CALL = toboolean(a)
                break
            else
                io.write(text)
                a = io.read()
            end
        elseif s == "str" then
            break
        elseif s == "split" then
            a = a:gsub('"',"")
            a = a:gsub("'","")
            a = split(a,",")
            break
        end
    end
    return a
end

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function write_file(file,text)
    local f = io.open(file,"w+")
    f:write(text)
    f:close()
end

local function read_file(file)
    local f = io.open(file,"rb")
    local a = f:read("*all")
    f:close()
    return a
end

local function get_script_path()
    local info = debug.getinfo(1,'S');
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    return script_path
end

local script_path = get_script_path()

local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('dir "'..directory..'" /b'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end

local function get_list_directory(file)
    return scandir(script_path..file)
end

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
    return "null"
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
            if type(k) ~= "number" then
            error("invalid table: mixed or invalid key types")
            end
            n = n + 1
        end
        if n ~= #val then
            error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"

        else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
            error("invalid table: mixed or invalid key types")
            end
            table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end


local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


function json.encode(val)
    return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
    -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepoint_to_utf8(n1)
    end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
        decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
        res = res .. str:sub(k, j - 1)
        j = j + 1
        local c = str:sub(j, j)
        if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                    or str:match("^%x%x%x%x", j + 1)
                    or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
        else
        if not escape_chars[c] then
            decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
        end
        k = j + 1

    elseif x == 34 then -- `"`: End of string
        res = res .. str:sub(k, j - 1)
        return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end


local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end


local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
        i = i + 1
        break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end


local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
        i = i + 1
        break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
        decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
        decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end


local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
}


parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

local function is_str_call(cond,text)
    if cond then
        return input_user(text)
    end
    return ""
end

local function is_int_call(cond,text)
    if cond then
        return tonumber(input_user(text,"int"))
    end
    return 60
end


local function table_into_str_rotat(tbl)
    local s = ""
    for _, a in pairs(tbl) do
        s = s..'"'..a..'"'..","
    end
    return s
end

local function gen_script_with_bot(decode,cfg,lst)
    -- decode --> template
    -- cfg --> json
    -- lst --> list bot
    local a = [[
if getBot().status ~= "online" then
    return
end
SLOT = 0
LIST_BOT = {]]..table_into_str_rotat(lst)..[[}
for idx, botlist in pairs(LIST_BOT) do
    if getBot().name:upper() == botlist:upper() then
        SLOT = idx
        break
    end
end
CONFIG = {
    Main_setting = {
        ItemID = ]]..decode.Main_setting.ItemID..[[,
        Pack = "]]..decode.Main_setting.Pack..[["
    },
    Farm_setting = {
        delay_harvest = 200,
        delay_plant = 200
    },
    Storage_setting = {
        storage_seed = "]]..decode.Storage_setting.storage_seed..[[",
        storage_seed_id = "]]..decode.Storage_setting.storage_seed_id..[[",
        storage_pack = "]]..decode.Storage_setting.storage_pack..[[",
        storage_pack_id = "]]..decode.Storage_setting.storage_pack_id..[["
    },
    Break_setting = {
        bool_break_other_world = false,
        break_world_name = "", 
        break_world_id = "",
        tile = ]]..decode.Break_setting.tile..[[,
        delay_break = 200, 
        delay_put = 200, 
        auto_ban_joined = false,
        owner = "",
        custom_position = {]]..tostring(decode.Break_setting.custom_position[1])..[[,]]..
        decode.Break_setting.custom_position[2]..[[,]]..decode.Break_setting.custom_position[3]..[[},
        disable_buypack = ]]..tostring(decode.Break_setting.disable_buypack).."\n\t},\n"..[[
    Other_setting = {
        repeat_world = ]]..tostring(decode.Other_setting.repeat_world)..[[,
        short_webhook = ]]..tostring(decode.Other_setting.short_webhook)..[[,
        disable_webhook = ]]..tostring(decode.Other_setting.disable_webhook).."\n\t},\n"..[[
    Custom_gems_buypack = {]]..tostring(decode.Custom_gems_buypack[1])..[[,]]..decode.Custom_gems_buypack[2]..[[},
    max_slot_backpack = ]]..decode.max_slot_backpack..[[,
    detect_floating_objects = ]]..tostring(decode.detect_floating_objects)..[[,
    disable_get_usage_cpu_ram = ]]..tostring(decode.disable_get_usage_cpu_ram)..[[,
    disable_plant = ]]..tostring(decode.disable_plant).."\n}"..[[
]]

    local c = ""
    for index = 1, #cfg do
        c = c .. [[
if SLOT == ]]..cfg[index].slot..[[ then 
    CONFIG.Main_setting.License = "]]..cfg[index].Main_setting.License..[["
    CONFIG.Farm_setting.farm_world = {]]..table_into_str_rotat(cfg[index].Farm_setting.farm_world).."}\n"..[[
    CONFIG.Farm_setting.farm_world_id = "]]..cfg[index].Farm_setting.farm_world_id..[["
    CONFIG.Other_setting.url_webhook = "]]..cfg[index].Other_setting.url_webhook..[["
end
]] .. "\n"
    end
    
    local c_c = [[
CONFIG.Custom_delay = {]].."\n\tuse_feature = "..tostring(decode.Custom_delay.use_feature)..","..
"\n\tdelay_break = "..decode.Custom_delay.delay_break..","..
"\n\tdelay_put = "..decode.Custom_delay.delay_put..","..
"\n\tdelay_harvest = "..decode.Custom_delay.delay_harvest..","..
"\n\tdelay_plant = "..decode.Custom_delay.delay_plant..","..
"\n\tdelay_findpath_harvest = 200"..","..
"\n\tdelay_findpath_plant = 200"..","..
"\n\tdelay_findpath_break = 800"..","..
"\n\tdelay_findpath_drop = 500"..","..
"\n\tdelay_findpath_other = 900"..","..
"\n\tdelay_drop = "..decode.Custom_delay.delay_drop..","..
"\n\tdelay_trash = "..decode.Custom_delay.delay_trash..","..
"\n\tdelay_warp = "..decode.Custom_delay.delay_warp..","..
"\n\tdelay_buypack = "..decode.Custom_delay.delay_buypack..","..
"\n\tdelay_upgrade_backpack = "..decode.Custom_delay.delay_upgrade_backpack.."\n"..[[}

CONFIG.notification = {]].."\n\tuse_feature = "..tostring(decode.notification.use_feature)..","..
'\n\turl_webhook = "'..decode.notification.url_webhook..'"'..","..
'\n\tusername = "'..decode.notification.username..'"'..","..
"\n\tschedule = {\n\t\tuse_schedule = false,\n\t\tdelay = 60\n\t}".."\n"..
[[}

CONFIG.say_random_word = true

CONFIG.auto_wear_pickaxe = {]].."\n\tuse_feature = "..tostring(decode.auto_wear_pickaxe.use_feature)..','..
'\n\tstorage_pickaxe = "'..decode.auto_wear_pickaxe.storage_pickaxe..'",'..
'\n\tstorage_pickaxe_id = "'..decode.auto_wear_pickaxe.storage_pickaxe_id..'"'.."\n"..[[}

CONFIG.PANDORA = true

CONFIG.skip_tutorial = ]]..tostring(decode.skip_tutorial)..[[
]]

    local d = [[
CONFIG = CONFIG
load(request("GET","https://raw.githubusercontent.com/jakob1234567890/rotation-premium/main/premium"))()
]]
    return a.."\n\n"..c.."\n"..c_c.."\n\n"..d
end


local home = {
    "---------- SETTING SCRIPT ALL PREMIUM ----------",
    "MENU : ",
    "1. New script / Add script",
    "2. Edit script",
    "3. New template",
    "4. Generate script",
    "5. Exit"
}

local home_new_script = {
    "---------- SETTING SCRIPT ALL PREMIUM ----------",
    "MENU : New script",
    "Template : ",
    "Filename : ",
    "slot : ",
    "1. Back to menu",
    "2. Exit"
}

local home_new_template = {
    "---------- SETTING SCRIPT ALL PREMIUM ----------",
    "MENU : New template",
    "Filename : ",
}

while true do
    ::back::
    os.execute("cls")

    print(
        home[1].."\n\n\n"..home[2].."\n"..home[3].."\n"..home[4].."\n"..home[5].."\n"..home[6].."\n"..home[7].."\n"
    )

    local choose_menu = input_user("Choose : ")

    if choose_menu == "1" then
        os.execute("cls")
        print(
            home_new_script[1].."\n\n\n"..home_new_script[2].."\n\n"
        )
        print(home_new_script[3])
        local list_dir = get_list_directory("\\data\\template")
        if #list_dir > 0 then
            for index, c in pairs(list_dir) do
                print(index..". "..c)
            end
        elseif list_dir <= 0 then
            print("Didn't found any template, exit program")
            return
        end 
        local choose_template = tonumber(input_user("\nChoose template : ","int"))
        os.execute("cls")
        print(
            home_new_script[1].."\n\n\n"..home_new_script[2].."\n\n"..home_new_script[3]..list_dir[choose_template].."\n\n"
        )

        local choose_filename = input_user(home_new_script[4])
        os.execute("cls")
        print(
            home_new_script[1].."\n\n\n"..home_new_script[2].."\n\n"..home_new_script[3]..
            list_dir[choose_template].."\n\n"..home_new_script[4]..choose_filename.."\n\n"
        )

        while true do
            ::slot_again::
            if file_exists("./data/output/"..choose_filename..".json") then
                local a = read_file("./data/output/"..choose_filename..".json")
                local b = read_file("./data/template/"..list_dir[choose_template].."")
                local decode = json.decode(b)
                local slot_decode = json.decode(a)
                local slot = tonumber(input_user(home_new_script[5],"int"))
                while #slot_decode + 1 < slot do
                    print("error, you didn't setting slot "..#slot_decode+1)
                    slot = tonumber(input_user(home_new_script[5],"int"))
                end
                os.execute("cls")
                print(
                    home_new_script[1].."\n\n\n"..home_new_script[2].."\n\n"..home_new_script[3]..
                    list_dir[choose_template].."\n\n"..home_new_script[4]..choose_filename.."\n\n"..
                    home_new_script[5]..slot.."\n\n"
                )

                slot_decode[slot] = {
                    slot = slot,
                    Main_setting = {
                        License = input_user("License : "),
                        ItemID = decode.Main_setting.ItemID,
                        Pack = decode.Main_setting.Pack
                    },
                    Farm_setting = {
                        farm_world = input_user("list_farm : ","split"),
                        farm_world_id = input_user("iddoor_farm_world : "),
                        delay_harvest = 200,
                        delay_plant = 200
                    },
                    Storage_setting = {
                        storage_seed = decode.Storage_setting.storage_seed,
                        storage_seed_id = decode.Storage_setting.storage_seed_id,
                        storage_pack = decode.Storage_setting.storage_pack,
                        storage_pack_id = decode.Storage_setting.storage_pack_id
                    },
                    Break_setting = {
                        bool_break_other_world = false,
                        break_world_name = "", 
                        break_world_id = "",
                        tile = decode.Break_setting.tile,
                        delay_break = 200, 
                        delay_put = 200, 
                        auto_ban_joined = false,
                        owner = "",
                        custom_position = decode.Break_setting.custom_position,
                        disable_buypack = decode.Break_setting.disable_buypack
                    },
                    Other_setting = {
                        repeat_world = decode.Other_setting.repeat_world,
                        url_webhook = input_user("url_webhook : "),
                        short_webhook = decode.Other_setting.short_webhook,
                        disable_webhook = decode.Other_setting.disable_webhook
                    },
                    Custom_gems_buypack = decode.Custom_gems_buypack,
                    max_slot_backpack = decode.max_slot_backpack,
                    detect_floating_objects = decode.detect_floating_objects,
                    disable_get_usage_cpu_ram = decode.disable_get_usage_cpu_ram,
                    disable_plant = decode.disable_plant,
                    Custom_delay = decode.Custom_delay,
                    notification = {
                        use_feature = false,
                        url_webhook = "",
                        username = "slot"..slot,
                        schedule = {
                            use_schedule = false,
                            delay = 60
                        }
                    },
                    say_random_word = true,
                    auto_wear_pickaxe = decode.auto_wear_pickaxe,
                    PANDORA = true,
                    skip_tutorial = decode.skip_tutorial
                }
                local encode = json.encode(slot_decode)
                write_file("./data/output/"..choose_filename..".json",encode)
            elseif not file_exists("./data/output/"..choose_filename..".json") then
                local slot = 1
                os.execute("cls")
                print(
                    home_new_script[1].."\n\n\n"..home_new_script[2].."\n\n"..home_new_script[3]..
                    list_dir[choose_template].."\n\n"..home_new_script[4]..choose_filename.."\n\n"..
                    home_new_script[5]..slot.."\n\n"
                )
                local CONFIG = {}
                local c = read_file("./data/template/"..list_dir[choose_template].."")
                local decode = json.decode(c)
                CONFIG[slot] = {
                    slot = slot,
                    Main_setting = {
                        License = input_user("License : "),
                        ItemID = decode.Main_setting.ItemID,
                        Pack = decode.Main_setting.Pack
                    },
                    Farm_setting = {
                        farm_world = input_user("list_farm : ","split"),
                        farm_world_id = input_user("iddoor_farm_world : "),
                        delay_harvest = 200,
                        delay_plant = 200
                    },
                    Storage_setting = {
                        storage_seed = decode.Storage_setting.storage_seed,
                        storage_seed_id = decode.Storage_setting.storage_seed_id,
                        storage_pack = decode.Storage_setting.storage_pack,
                        storage_pack_id = decode.Storage_setting.storage_pack_id
                    },
                    Break_setting = {
                        bool_break_other_world = false,
                        break_world_name = "", 
                        break_world_id = "",
                        tile = decode.Break_setting.tile,
                        delay_break = 200, 
                        delay_put = 200, 
                        auto_ban_joined = false,
                        owner = "",
                        custom_position = decode.Break_setting.custom_position,
                        disable_buypack = decode.Break_setting.disable_buypack
                    },
                    Other_setting = {
                        repeat_world = decode.Other_setting.repeat_world,
                        url_webhook = input_user("url_webhook : "),
                        short_webhook = decode.Other_setting.short_webhook,
                        disable_webhook = decode.Other_setting.disable_webhook
                    },
                    Custom_gems_buypack = decode.Custom_gems_buypack,
                    max_slot_backpack = decode.max_slot_backpack,
                    detect_floating_objects = decode.detect_floating_objects,
                    disable_get_usage_cpu_ram = decode.disable_get_usage_cpu_ram,
                    disable_plant = decode.disable_plant,
                    Custom_delay = decode.Custom_delay,
                    notification = {
                        use_feature = false,
                        url_webhook = "",
                        username = "slot"..slot,
                        schedule = {
                            use_schedule = false,
                            delay = 60
                        }
                    },
                    say_random_word = true,
                    auto_wear_pickaxe = decode.auto_wear_pickaxe,
                    PANDORA = true,
                    skip_tutorial = decode.skip_tutorial
                }
                local encode = json.encode(CONFIG)
                write_file("./data/output/"..choose_filename..".json",encode)
            end
            print("Success!\n")
            print(home_new_script[6].."\n".."2. Setting again".."\n"..home_new_script[7].."\n\n")
            local choose_next_new_script = tonumber(input_user("Choose : ","int"))
            if choose_next_new_script == 1 then
                goto back
            elseif choose_next_new_script == 2 then
                goto slot_again
            elseif choose_next_new_script == 3 then
                return
            else
                while choose_next_new_script ~= 1 or choose_next_new_script ~= 2 or choose_next_new_script ~= 3 do
                    choose_next_new_script = tonumber(input_user("Choose : ","int"))
                end
            end
        end
        
    elseif choose_menu == "2" then
        print("Soon")
        return
    elseif choose_menu == "3" then
        os.execute("cls")
        print(
            home_new_template[1].."\n\n\n"..home_new_template[2].."\n\n"
        )
        local choose_filename = input_user(home_new_template[3])
        os.execute("cls")
        print(
            home_new_template[1].."\n\n\n"..home_new_template[2].."\n\n\n"..home_new_template[3]..choose_filename.."\n\n".."Please write correctly\n\n"
        )
        local CONFIG = {
            Main_setting = {
                ItemID = tonumber(input_user("itemid : ","int")),
                Pack = input_user("debug_pack : ")
            },
            Storage_setting = {
                storage_seed = input_user("storage_seed : "),
                storage_seed_id = input_user("iddoor_storage_seed : "),
                storage_pack = input_user("storage_pack : "),
                storage_pack_id = input_user("iddoor_storage_pack : ")
            },
            Break_setting = {
                tile = tonumber(input_user("tile : ","int")),
                custom_position = {toboolean(input_user("custom_position : ",true)), tonumber(input_user("position_custom_x : ","int")), tonumber(input_user("position_custom_y : ","int"))},
                disable_buypack = toboolean(input_user("disable_buypack : ",true))
            },
            Other_setting = {
                repeat_world = toboolean(input_user("repeat_world : ",true)),
                short_webhook = toboolean(input_user("short_webhook : ",true)),
                disable_webhook = toboolean(input_user("disable_webhook : ",true))
            },
            Custom_gems_buypack = {
                toboolean(input_user("Custom_gems_buypack : ",true)), is_int_call(CALL,"trigger : ")
            },
            max_slot_backpack = tonumber(input_user("max_slot_backpack : ","int")),
            detect_floating_objects = toboolean(input_user("detect_floating_objects : ",true)),
            disable_get_usage_cpu_ram = toboolean(input_user("disable_get_usage_cpu_ram : ",true)),
            disable_plant = toboolean(input_user("disable_plant : ",true)),
            Custom_delay = {
                use_feature = toboolean(input_user("Custom_delay : ",true)),
                delay_break = is_int_call(CALL,"delay_break [millisecond] : "),
                delay_put = is_int_call(CALL,"delay_put [millisecond] : "),
                delay_harvest = is_int_call(CALL,"delay_harvest [millisecond] : "),
                delay_plant = is_int_call(CALL,"delay_plant [millisecond] : "),
                delay_findpath_harvest = 200,
                delay_findpath_plant = 200,
                delay_findpath_break = 800,
                delay_findpath_drop = 500,
                delay_findpath_other = 900,
                delay_drop = is_int_call(CALL,"delay_drop [second] : "),
                delay_trash = is_int_call(CALL,"delay_trash [second] : "),
                delay_warp = is_int_call(CALL,"delay_warp [second] : "),
                delay_buypack = is_int_call(CALL,"delay_buypack [second] : "),
                delay_upgrade_backpack = is_int_call(CALL,"delay_upgrade_backpack [second] : ")
            },
            notification = {
                use_feature = toboolean(input_user("get notification bot if offline : ",true)),
                url_webhook = is_str_call(CALL,"url_webhook_notification : "),
                username = is_str_call(CALL,"username_webhook_notification : "),
                schedule = {
                    use_schedule = false,
                    delay = 60
                }
            },
            auto_wear_pickaxe = {
                use_feature = toboolean(input_user("auto_wear_pickaxe : ",true)),
                storage_pickaxe = is_str_call(CALL,"storage_pickaxe : "),
                storage_pickaxe_id = is_str_call(CALL,"iddoor_storage_pickaxe : ")
            },
            skip_tutorial = toboolean(input_user("skip_tutorial : ",true))
        }
        local encode = json.encode(CONFIG)
        write_file("./data/template/"..choose_filename..".template.json",encode)
        os.execute("cls")
        print(
            home_new_template[1].."\n\n\n".."1. Back to menu\n2. Exit"
        )
        local choose_enc_ = input_user("\n\nChoose : ")
        if choose_enc_ == "2" then
            return
        end
    elseif choose_menu == "4" then
        print("\n1. With bot\n2. With slot")
        local choose_config_generate = input_user("\nChoose : ")
        if choose_config_generate == "1" then
            print("Filename template : ")
            local list_dir_template = get_list_directory("\\data\\template")
            if #list_dir_template > 0 then
                for index, c in pairs(list_dir_template) do
                    print(index..". "..c)
                end
            elseif list_dir_template <= 0 then
                print("Didn't found any template, exit program")
                return
            end
            local choose_template = tonumber(input_user("\nChoose template : ","int"))
            print(
                "\n\n"..home_new_script[3]..list_dir_template[choose_template].."\n\n"
            )

            print("Filename data : ")
            local list_dir_data = get_list_directory("\\data\\output")
            if #list_dir_data > 0 then
                for index, c in pairs(list_dir_data) do
                    print(index..". "..c)
                end
            elseif list_dir_data <= 0 then
                print("Didn't found any data, exit program")
                return
            end

            local choose_filename = tonumber(input_user("Choose "..home_new_script[4],"int"))
            print(
                "\n\n"..home_new_script[4]..list_dir_data[choose_filename].."\n\n"
            )
            local encode_template = json.decode(read_file("./data/template/"..list_dir_template[choose_template]))
            local encode_data = json.decode(read_file("./data/output/"..list_dir_data[choose_filename]))
            local list_bot = input_user("Your list bot : ","split")
            write_file("./data/generate/script.txt",gen_script_with_bot(encode_template,encode_data,list_bot))
            return
        end
    end
end
