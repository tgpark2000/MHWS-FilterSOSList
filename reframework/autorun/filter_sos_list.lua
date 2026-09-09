local fs, imgui, io, json, log, math, os, pcall, re, sdk, string, table, thread, tonumber, tostring, type, ValueType, Vector2f, Vector3f, Vector4f, xpcall = fs, imgui, io, json, log, math, os, pcall, re, sdk, string, table, thread, tonumber, tostring, type, ValueType, Vector2f, Vector3f, Vector4f, xpcall

local MOD_TITLE <const>   = "Filter SOS List"
local CONFIG_FILE <const> = string.gsub(MOD_TITLE, " ", "_"):lower() .. ".json"
local is_window_open      = false

local cursor_helper 
xpcall(function() cursor_helper = require("_lib._CursorDrawHelper") end, function() cursor_helper = { failed_require = true, draw_custom_cursor = function()
        if reframework:is_drawing_ui() or not is_window_open then return end

        local mouse_pos   = imgui.get_mouse()
        local window_size = imgui.get_window_size()
        local window_pos  = imgui.get_window_pos()
        local is_hovered  = (mouse_pos.x >= window_pos.x) and (mouse_pos.x <= window_pos.x + window_size.x) and (mouse_pos.y >= window_pos.y) and (mouse_pos.y <= window_pos.y + window_size.y)
        if not is_hovered then return end

        local draw_list = imgui.get_foreground_draw_list()
        if not draw_list then return end

        local lime_green    = 0xFF80FF80 
        local outline_color = 0xFF000000
        local p1            = mouse_pos
        local p2            = Vector2f.new(mouse_pos.x + 20, mouse_pos.y + 10)
        local p3            = Vector2f.new(mouse_pos.x + 5,  mouse_pos.y + 25)

        draw_list:add_triangle_filled(p1, p2, p3, lime_green)
        draw_list:add_triangle(p1, p2, p3, outline_color, 1.5)
    end } 
end)

local enemy_def            = sdk.find_type_definition("app.EnemyDef")
local get_em_name          = enemy_def:get_method("EnemyName(app.EnemyDef.ID)")
local get_is_em_valid      = enemy_def:get_method("isValid(app.EnemyDef.ID)")
local get_is_em_boss       = enemy_def:get_method("isBossID(app.EnemyDef.ID)")
local get_em_species_fixed = enemy_def:get_method("Species(app.EnemyDef.ID)") -- return app.EnemyDef.SPECIES_Fixed == (app.EnemyDef.SPECIES + 1)
local get_em_species_data  = enemy_def:get_method("Data(app.EnemyDef.SPECIES)")
local get_item_name        = sdk.find_type_definition("app.ItemDef"):get_method("NameString(app.ItemDef.ID)")
local convert_guid_to_text = sdk.find_type_definition("app.MessageUtil"):get_method("getText(System.Guid, System.Int32)")
local system_guid          = sdk.find_type_definition("System.Guid")
local try_parse_guid       = system_guid:get_method("Parse(System.String)")
local create_system_guid   = function(guid_string) return try_parse_guid and try_parse_guid:call(nil, guid_string) end

local config = {
    enabled = true,
    general_filters = {
        enabled = true,
        monster_name = { 
            enabled = false,
            list    = {}, -- ["enemy id"] = boolean
        },
        monster_count = {
            enabled    = false, 
            value      = 1,
            comparison = "at least",
        },
        monster_threat = {
            enabled    = false,
            value      = 3,
            comparison = "at least",
        },
        monster_species = {
            enabled = false,
            value   = 1,
        },
        quest_level = {
            enabled    = false,
            value      = 7,
            comparison = "at least",
        },
        host_hr = {
            enabled   = false,
            min       = 0,
            max       = 1000,
            threshold = {
                enabled    = false,
                value      = 9,
                comparison = "at least",
            },
        },
        current_players = {
            enabled    = false,
            value      = 1,
            comparison = "at least",
        },
        max_players = {
            enabled    = false,
            value      = 4,
            comparison = "at most",
        },
        wishlist = {
            enabled = false,
        },        
        quest_join_approval = {
            enabled = true,
            value   = "Auto",
        },
        quest_started_time = {
            enabled = false,
            value = 1,
        },
        quest_multiplay_setting = {
            enabled = false,
            value   = "Player & NPCs",
        },
        quest_fields = {
            enabled = false,
            list    = { ["Plains"] = false, ["Forest"] = false, ["Basin"] = false, ["Cliffs"] = false, ["Wyveria"] = false, ["Wounded Hollow"] = false, ["Rimechain Peak"] = false, ["Dragontorch Shrine"] = false, ["Forgotten Machineworks"] = false },
        },
        quest_environment  = {
            enabled = false,
            list    = { ["Plenty"] = false, ["Fallow"] = false, ["Inclemency"] = false }
        },
    },
    item_filters = {
        enabled = false,
        mode    = "Custom",
        custom = {
            operator    = "AND",
            target_list = { -- ["item_id"] = number or false
                ["469"]      = false,
                ["470"]      = false,
                ["478"]      = false,
                ["157"]      = false,
                ["620"]      = false,
                ["653"]      = false,
                ["820"]      = false,
                ["WISHLIST"] = false,
                ["GEM"]      = false,
            },
        },
        max_quantity = {
            target_item = "469",
        },
    },
    lobby_member_quest_filters = {
        enabled          = false,
        without_password = {
            enabled = false
        },
        quest_join_approval = {
            enabled = false,
            value   = "Auto",
        },
        joinable_quest = {
            enabled = false,
        },
    },
    cursor_scale = 1.5,
}

local ITEM_ID_MAP <const> = {
    ["469"]      = "Basic Material",           -- 보통 소재
    ["470"]      = "Valuable Material",        -- 높은 가치를 지닌 소재
    ["478"]      = "Ancient Weapon Fragment",  -- 낡은 무기 조각
    ["157"]      = "Ancient Orb - Armor",      -- 낡은 구슬 - 갑
    ["620"]      = "Ancient Orb - Sword",      -- 낡은 구슬 - 검
    ["653"]      = "Heavy Armor Sphere",       -- 중갑옥
    ["820"]      = "Glowing Stone",            -- 빛나는 부적
    ["WISHLIST"] = "Wishlisted Item", 
    ["GEM"]      = "Monster Gem",
}

local ITEM_NAME_MAP <const> = {
    ["Basic Material"]          = "469",
    ["Valuable Material"]       = "470",
    ["Ancient Weapon Fragment"] = "478",
    ["Ancient Orb - Armor"]     = "157",
    ["Ancient Orb - Sword"]     = "620",
    ["Heavy Armor Sphere"]      = "653",
    ["Glowing Stone"]           = "820",
}

local GEM_ID_LIST <const>            = { "36", "91", "333", "350", "387", "423", "436", "451", "464", "485", "533", "567", "105", "704", "559", "716", "726", "553", "734" }

local COMPARISON_TYPE_LIST <const>   = {  "at least",       "at most",       "exactly" }
local COMPARISON_TYPE_LOOKUP <const> = { ["at least"] = 1, ["at most"] = 2, ["exactly"] = 3 }
local EVALUATORS <const>             = {
    ["at least"] = function(a, b) return (a >= b) end,
    ["at most"]  = function(a, b) return (a <= b) end,
    ["exactly"]  = function(a, b) return (a == b) end,
}

local MULTIPLAY_TYPE_LIST <const>   = {  "Players & NPCs",       "Players" }
local MULTIPLAY_TYPE_LOOKUP <const> = { ["Players & NPCs"] = 1, ["Players"] = 2 }

local FILTER_MODE_LIST <const>   = {  "Custom",       "Max Quantity" }
local FILTER_MODE_LOOKUP <const> = { ["Custom"] = 1, ["Max Quantity"] = 2 }

local FIELD_LIST <const>   = {       "Plains",       "Forest",       "Basin",       "Cliffs",       "Wyveria",       "Wounded Hollow",        "Rimechain Peak",        "Dragontorch Shrine",        "Forgotten Machineworks" }
local FIELD_ID_MAP <const> = { [0] = "Plains", [1] = "Forest", [2] = "Basin", [3] = "Cliffs", [4] = "Wyveria", [9] = "Wounded Hollow", [10] = "Rimechain Peak", [11] = "Dragontorch Shrine", [13] = "Forgotten Machineworks" }

local ENVIRONMENT_LIST <const>    = {       "Plenty",       "Fallow",       "Inclemency" }
local ENVIRONMENT_ID_MAP <const>  = { [2] = "Plenty", [0] = "Fallow", [1] = "Inclemency" }

local ACCEPT_MODE_LIST <const>   = {  "Auto",          "Manual" }
local ACCEPT_MODE_LOOKUP <const> = { ["Auto"] = 1,    ["Manual"] = 2 }
local is_auto_accept <const>     = { ["Auto"] = true, ["Manual"] = false }

local LOCALIZED_TEXT_MAP = {}
local GUID_MAP <const>   = {
    ["Plains"]                  = "e232918e-ee5a-4723-9618-ad8799eb8dc1",
    ["Forest"]                  = "ce61d1bb-48ba-4256-b321-a98c7699abd0",
    ["Basin"]                   = "7cd70789-f7e1-439f-adb5-dcc84155329c",
    ["Cliffs"]                  = "05c57b50-8a37-45d8-8270-d0b7d9e26d41",
    ["Wyveria"]                 = "edf6ca79-4396-4fc2-a9bf-ecddbb41020f",
    ["Wounded Hollow"]          = "96c9fa8f-0ac2-4351-a636-363fef236722",
    ["Rimechain Peak"]          = "bf7c1e0b-41ef-4a42-bbdb-b8cbb56089fa",
    ["Dragontorch Shrine"]      = "e1d6d887-5bb9-4246-b08c-eb540a49947f",
    ["Forgotten Machineworks"]  = "8c000ff9-6104-47c4-a616-af6a7510b6fd",
    ["Plenty"]                  = "1652ff9a-674d-4432-a348-25c28375602a",
    ["Fallow"]                  = "4756804f-e6cb-4b8f-8f87-7357b0087c76",
    ["Inclemency"]              = "7b5b392e-4e61-4f21-9ad6-9b50711d879c",
}

local function get_localized_text(key)
    local text = LOCALIZED_TEXT_MAP[key]
    if text then return text end

    if (type(key) == "string") then  -- Maybe guid-string
        local guid_str = GUID_MAP[key]
        if not guid_str then return key end

        local guid = create_system_guid(guid_str)
        if not guid then return key end

        text = convert_guid_to_text:call(nil, guid, 0)
        if not text then return key end
    elseif (type(key) == "number") then  -- Maybe app.ItemDef.ID
        text = get_item_name:call(nil, key)
        if not text then return key end

        LOCALIZED_TEXT_MAP[ITEM_ID_MAP[tostring(key)]] = text    
    end

    LOCALIZED_TEXT_MAP[key] = text
    return text
end

local ENEMY_BOSS = {
    NAME_LIST       = {}, -- array
    NAME_MAP        = {}, 
    ID_MAP          = {}, 
    SPECIES_MAP     = {}, -- hash map: ["species id"] = species string
    INVALID_SPECIES = sdk.find_type_definition("app.EnemyDef.SPECIES_Fixed"):get_field("INVARID"):get_data() or 0,  -- 필드명이 'INVARID' 였다
}
function ENEMY_BOSS.update()
    local enemy_def_id = sdk.find_type_definition("app.EnemyDef.ID")
    if not enemy_def_id then return 60 end

    local conf_name_list = config.general_filters.monster_name.list
    ENEMY_BOSS.NAME_MAP     = {}
    ENEMY_BOSS.ID_MAP       = {}
    ENEMY_BOSS.NAME_LIST    = {}
    ENEMY_BOSS.SPECIES_MAP  = {}
    local width             = 0
    local fields            = enemy_def_id:get_fields()
    for i, field in ipairs(fields) do
        repeat
            if not field:is_static() then break end
            local id = field:get_data()
            if not get_is_em_valid:call(nil, id) or not get_is_em_boss:call(nil, id) then break end
            local specics_fixed = get_em_species_fixed:call(nil, id)
            if (specics_fixed == ENEMY_BOSS.INVALID_SPECIES) then break end

            local specics_data  = get_em_species_data:call(nil, specics_fixed - 1)
            local guid_specics  = specics_data:get_EmSpeciesName()
            local guid_name     = get_em_name:call(nil, id)
            local name          = convert_guid_to_text:call(nil, guid_name, 0)
            local specics_type  = convert_guid_to_text:call(nil, guid_specics, 0)
            local size_x        = imgui.calc_text_size(specics_type).x
            if (size_x > width) then width = size_x end
            id                                    = tostring(id)
            ENEMY_BOSS.NAME_MAP[name]             = id
            ENEMY_BOSS.ID_MAP[id]                 = name
            ENEMY_BOSS.SPECIES_MAP[specics_fixed] = specics_type
            table.insert(ENEMY_BOSS.NAME_LIST, name)
            if (conf_name_list[id] == nil) then conf_name_list[id] = false end
        until true
    end
    return (width + 30)
end

local ITEM_FILTERS ={
    MAX_QUANTITY = {
        list   = { "Basic Material", "Valuable Material", "Ancient Weapon Fragment", "Ancient Orb - Armor", "Ancient Orb - Sword", "Heavy Armor Sphere", "Glowing Stone" },
        lookup = { ["469"] = 1, ["470"] = 2, ["478"] = 3, ["157"] = 4, ["620"] = 5, ["653"] = 6, ["820"] = 7 },
    },
    CUSTOM_MODE = {
        operators       = {  "AND",       "OR" },
        operator_lookup = { ["AND"] = 1, ["OR"] = 2 },
        list            = {},
        lookup          = {},
        selected_index  = 1,
    },
}
function ITEM_FILTERS.CUSTOM_MODE.update()
    local target_items     = config.item_filters.custom.target_list
    local filtering        = ITEM_FILTERS.CUSTOM_MODE
          filtering.list   = {}
          filtering.lookup = {}

    for item_id, item_name in pairs(ITEM_ID_MAP) do
        if (target_items[item_id] == nil) then target_items[item_id] = false end
        if not target_items[item_id] then
            table.insert(filtering.list, get_localized_text(tonumber(item_id) or item_id))
            filtering.lookup[#filtering.list] = item_id
        end
    end
end

local UI_WIDTH = {
    enemy_species         = 60,
    comparison_types      = 30,
    multiplay_types       = 60,
    filter_modes          = 40,
    custom_mode_operators = 30,
    localized_items       = 80,
    accept_modes          = 40,
}
function UI_WIDTH.update()
    local width = 0
    for i, text in pairs(COMPARISON_TYPE_LIST) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.comparison_types = width + 30

    width = 0
    for i, text in pairs(MULTIPLAY_TYPE_LIST) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.multiplay_types = width + 30

    width = 0
    for i, text in pairs(ACCEPT_MODE_LIST) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.accept_modes = width + 30

    width = 0
    for i, text in pairs(FILTER_MODE_LIST) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.filter_modes = width + 30

    width = 0 
    for item_id, item_name in pairs(ITEM_ID_MAP) do 
        local size = imgui.calc_text_size(get_localized_text(tonumber(item_id) or item_id)).x
        if (size > width) then width = size end
    end
    UI_WIDTH.localized_items = width + 30
    
    width = 0
    for i, text in pairs(ITEM_FILTERS.CUSTOM_MODE.operators) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.custom_mode_operators = width + 30
end

local function is_contains(array, element)
    if (type(array) ~= "table") or (element == nil) then return false end
    for _, value in pairs(array) do
        if (value == element) then return true end
    end
    return false
end

local function array_is_equal(a, b)
    if (type(a) ~= "table") or (type(b) ~= "table") then return false end
    if #a ~= #b                                     then return false end
    for key, value in pairs(a) do
        if (type(value) == "table") then 
            if not array_is_equal(value, b[key]) then return false end
        elseif (b[key]  ~= value)                then return false end
    end
    for key in pairs(b) do 
        if (a[key] == nil) then return false end
    end
    return true
end

local function array_deep_copy(from)
    local ary = {}
    if (from == nil)           then return ary  end
    if (type(from) ~= "table") then return from end
    for key, value in pairs(from) do 
        ary[key] = (type(value) == "table") and array_deep_copy(value) or value 
    end
    return ary
end

local function merge_config(config, loaded)
    if (type(config) ~= "table") or (type(loaded) ~= "table") then return end

    for key, value in pairs(config) do
        if (loaded[key] ~= nil) then 
            if (type(value) == "table") and (type(loaded[key]) == "table") then merge_config(value, loaded[key])
            else                                                                config[key] = loaded[key]        end
        end
    end
end

local old_config = nil
local function save_config(force)
    if (not force) and ((not old_config) or array_is_equal(config, old_config)) then return end
    json.dump_file(CONFIG_FILE, config)
    old_config = array_deep_copy(config)
end

local function load_config()
    if old_config then return end
    local loaded = json.load_file(CONFIG_FILE)
    if not loaded then save_config(true) return end 
    if (type(loaded) == "table") then merge_config(config, loaded) end
    old_config = array_deep_copy(config)
end 

local function initialize()  
    LOCALIZED_TEXT_MAP     = {}  -- 옵션의 문자 언어 설정 변경하는 경우를 대비해서 항상 초기화한다.
    UI_WIDTH.enemy_species = ENEMY_BOSS.update()

    load_config()
    UI_WIDTH.update()
    ITEM_FILTERS.CUSTOM_MODE.update()
end initialize()
sdk.hook(sdk.find_type_definition("app.GUI020001"):get_method(".ctor()"), function(args) initialize() end) 

local function filter_reward_items(reward_table)
    local conf          = config.item_filters.custom
    local is_logical_or = (conf.operator == "OR")
    for item_id, min_required in pairs(conf.target_list) do
        if min_required then
            local amount = reward_table[item_id] or 0
            if (amount >= min_required) then if     is_logical_or then return false end 
            else                             if not is_logical_or then return true  end end
        end
    end
    return is_logical_or
end

local reward_util         = sdk.find_type_definition("app.ExQuestRewardUtil")
local export_rewards      = reward_util:get_method("exportExRewardInfoToItemWorkList(app.cExEnemyRewardItemInfo)")
local wishlist_util       = sdk.find_type_definition("app.WishlistUtil")
local is_wishlist_item    = wishlist_util:get_method("isItemRequiredForWishlist(app.ItemDef.ID)")
local is_wishlist_quest   = wishlist_util:get_method("isExQuestRequiredForWishlist(app.cExEnemyRewardItemInfo, app.EnemyDef.ID[], app.EnemyDef.ROLE_ID[], app.EnemyDef.LEGENDARY_ID[], app.QuestDef.RANK, app.QuestDef.EM_REWARD_RANK[], System.Boolean)") 
local is_wishlist_mission = wishlist_util:get_method("isQuestRequiredForWishlist(app.MissionIDList.ID, app.QuestDef.RANK)")
local function filter_sos_quest_list(quest_list)
    if not quest_list then return end

    local quest_list_size = quest_list:get_Count()
    if quest_list_size == 0 then return end 

    local quests_to_remove = {}
    local max_quantity     = 0
    local conf

    for i = 0, quest_list_size - 1 do
        local should_remove = false
        repeat
            local quest_data = quest_list:get_Item(i)
            if not quest_data then break end

            local quest_level   = quest_data:get_QuestLv()
            local monster_ids   = quest_data:get_TargetEmId() -- app.EnemyDef.ID[] get_TargetEmId()
            local monster_count = monster_ids:get_size()
            local session_data  = quest_data.Session
            local search_result = session_data:get_SearchResult()  -- app.net_session_manager.SessionManager.cSearchResultQuest

            local filters = config.general_filters
            if filters.enabled then
                conf = filters.quest_join_approval
                if conf.enabled then
                    if (is_auto_accept[conf.value] ~= search_result.isAutoAccept) then should_remove = true; break end
                end

                conf = filters.quest_started_time
                if conf.enabled then
                    local started_at         = (search_result.startedAt > 0) and search_result.startedAt or search_result.acceptedAt
                    local started_difference = (os.time() - started_at) / 60
                    if (started_difference >= conf.value) then should_remove = true; break end
                end

                conf = filters.quest_multiplay_setting
                if conf.enabled and (search_result.multiplaySetting ~= (MULTIPLAY_TYPE_LOOKUP[conf.value] - 1)) then should_remove = true; break end

                conf = filters.quest_fields
                if conf.enabled then
                    local field = FIELD_ID_MAP[search_result.fieldId]
                    if not conf.list[field] then should_remove = true; break end
                end

                conf = filters.quest_environment
                if conf.enabled then
                    local environment = ENVIRONMENT_ID_MAP[search_result.envType]
                    if not conf.list[environment] then should_remove = true; break end
                end

                conf = filters.monster_name
                if conf.enabled then
                    local found = false
                    for k = 0, monster_count - 1 do 
                        local em_id = monster_ids:get_Item(k)
                        if conf.list[tostring(em_id)] then found = true; break end
                    end
                    if not found then should_remove = true; break end
                end

                conf = filters.monster_count
                if conf.enabled then
                    local comparison = conf.comparison or COMPARISON_TYPE_LIST[1]
                    local evaluator  = EVALUATORS[comparison]
                    if not evaluator or not evaluator(monster_count, conf.value) then should_remove = true; break end
                end

                conf = filters.monster_threat
                if conf.enabled then
                    local monster_difficulties       = quest_data:getTragetEmDifficulityRank()  -- 게임 API 자체 오타였다
                    local monster_difficulties_count = monster_difficulties:get_size()
                    local comparison                 = conf.comparison or COMPARISON_TYPE_LIST[1]
                    local evaluator                  = EVALUATORS[comparison]
                    local found                      = false
                    for diff_index = 0, monster_difficulties_count - 1 do
                        local monster_difficulty = monster_difficulties:get_Item(diff_index)
                        if evaluator and evaluator(monster_difficulty, conf.value) then found = true; break end
                    end
                    if not found then should_remove = true; break end
                end

                conf = filters.quest_level
                if conf.enabled then
                    local comparison = conf.comparison or COMPARISON_TYPE_LIST[1]
                    local evaluator  = EVALUATORS[comparison]
                    if not evaluator or not evaluator(quest_level, conf.value) then should_remove = true; break end
                end

                conf = filters.host_hr
                if conf.enabled then
                    local host_info  = search_result:getHostHunterInfo()
                    local host_hr    = host_info and host_info.hr or 1
                    local min, max   = conf.min, conf.max
                    local need_check = true
                    local threshold  = conf.threshold
                    if threshold.enabled then
                        local comparison = threshold.comparison or COMPARISON_TYPE_LIST[1]
                        local evaluator  = EVALUATORS[comparison]
                        if not (evaluator and evaluator(quest_level, threshold.value)) then need_check = false end
                    end
                    if need_check and ((host_hr <= min) or (host_hr >= max)) then should_remove = true; break end
                end

                conf = filters.monster_species
                if conf.enabled then
                    local found = false
                    for k = 0, monster_count - 1 do 
                        local species_fixed = get_em_species_fixed:call(nil, monster_ids:get_Item(k))
                        if species_fixed == conf.value then found = true; break end
                    end
                    if not found then should_remove = true; break end
                end

                conf = filters.current_players
                if conf.enabled then
                    local current_players = search_result.memberNum
                    local comparison      = conf.comparison or COMPARISON_TYPE_LIST[3]
                    local evaluator       = EVALUATORS[comparison]
                    if not evaluator or not evaluator(current_players, conf.value) then should_remove = true; break end
                end

                conf = filters.max_players
                if conf.enabled then
                    local max_players = search_result.maxMemberNum
                    local comparison  = conf.comparison or COMPARISON_TYPE_LIST[1]
                    local evaluator   = EVALUATORS[comparison]
                    if not evaluator or not evaluator(max_players, conf.value) then should_remove = true; break end
                end

                conf = filters.wishlist
                if conf.enabled then
                    local is_quest_wishlisted = false
                    local active_quest        = quest_data:get_ActiveQuestData()
                    local quest_rank          = search_result.questRank           -- app.QuestDef.RANK
                    if active_quest then
                        local mission_id = active_quest:get_MissionId()
                        if (mission_id ~= -1) then is_quest_wishlisted = is_wishlist_mission:call(wishlist_util, mission_id, quest_rank) end
                    end
                    if not is_quest_wishlisted then
                        local quest_reward_obj    = quest_data:get_ExEnemyRewardItemInfo()  -- app.cExEnemyRewardItemInfo get_ExEnemyRewardItemInfo()
                        local quest_role_ids      = quest_data:get_TargetEmRoleId()         -- app.EnemyDef.ROLE_ID[] get_TargetEmRoleId()
                        local quest_legendary_ids = quest_data:get_TargetEmLegendaryId()    -- app.EnemyDef.LEGENDARY_ID[] get_TargetEmLegendaryId()
                        local quest_reward_ranks  = quest_data:getTargetEmRewardRank()      -- app.QuestDef.EM_REWARD_RANK[]
                              is_quest_wishlisted = is_wishlist_quest:call(wishlist_util, quest_reward_obj, monster_ids, quest_role_ids, quest_legendary_ids, quest_rank, quest_reward_ranks, true) 
                    end
                    if not is_quest_wishlisted then should_remove = true; break end
                end
            end

            conf = config.item_filters
            if conf.enabled then
                local reward_table     = {}
                local quest_reward_obj = quest_data:get_ExEnemyRewardItemInfo()  -- app.cExEnemyRewardItemInfo get_ExEnemyRewardItemInfo()
                local item_work_list   = export_rewards:call(reward_util, quest_reward_obj)
                local is_custom_mode   = (conf.mode == "Custom")
                for item_i = 0, item_work_list._size - 1 do
                    local item_work                = item_work_list:get_Item(item_i)
                    local item_id                  = tostring(item_work:get_ItemId())
                    local item_num                 = item_work.Num or 0
                    local quest_reward_on_wishlist = nil
                    if is_custom_mode                    then quest_reward_on_wishlist = is_wishlist_item:call(wishlist_util, tonumber(item_id))                 end
                    if quest_reward_on_wishlist          then reward_table["WISHLIST"] = (reward_table["WISHLIST"] and reward_table["WISHLIST"] or 0) + item_num end
                    if is_contains(GEM_ID_LIST, item_id) then item_id                  = "GEM"                                                                   end

                    reward_table[item_id] = (reward_table[item_id] and reward_table[item_id] or 0) + item_num
                end

                if is_custom_mode and filter_reward_items(reward_table) then should_remove = true; break end

                local item_num = reward_table[conf.max_quantity.target_item] or 0
                if not is_custom_mode then  
                    if     not item_num or (item_num < max_quantity) then should_remove = true     break 
                    elseif (item_num > max_quantity)                 then max_quantity  = item_num end 
                end
            end
        until true
        
        if should_remove and not is_contains(quests_to_remove, i) then table.insert(quests_to_remove, i) end
    end

    for index = #quests_to_remove, 1, -1 do
        quest_list:RemoveAt(quests_to_remove[index])
    end

    conf = config.item_filters
    if conf.enabled and (conf.mode == "Max Quantity") then
              conf  = conf.max_quantity
        local count = quest_list:get_Count()
        for i = (count - 1), 0, -1 do
            if (max_quantity == 0) then quest_list:RemoveAt(i)
            else
                local quest_data       = quest_list:get_Item(i)
                local quest_reward_obj = quest_data:get_ExEnemyRewardItemInfo()
                local item_work_list   = export_rewards:call(reward_util, quest_reward_obj)
                local total_quantity   = 0
                for index = 0, item_work_list._size - 1 do
                    local item_work = item_work_list:get_Item(index)
                    if (conf.target_item == tostring(item_work:get_ItemId())) then total_quantity = total_quantity + item_work.Num end
                end
                if (total_quantity < max_quantity) then quest_list:RemoveAt(i) end
            end
        end
    end
end

local NPC_ONLY <const> = sdk.find_type_definition("app.net_quest_session.cCreateQuestSessionInfo.MULTIPLAY_SETTING"):get_field("NPC_ONLY"):get_data() or 2
local function filter_lobby_member_quest_list(quest_list)
    if not quest_list then return end

    local quest_list_size = quest_list:get_Count()
    if quest_list_size == 0 then return end 

    local quests_to_remove = {}
    local filters          = config.lobby_member_quest_filters

    for i = 0, quest_list_size - 1 do
        local should_remove = false
        repeat
            local quest_data = quest_list:get_Item(i)
            if not quest_data then break end

            local session_data  = quest_data.Session
            local search_result = session_data:get_SearchResult()  -- app.net_session_manager.SessionManager.cSearchResultQuest

            local conf = filters.without_password
            if conf.enabled then
                if session_data:get_IsNeedPassword() then should_remove = true; break end
            end

            conf = filters.quest_join_approval
            if conf.enabled then
                if (is_auto_accept[conf.value] ~= search_result.isAutoAccept) then should_remove = true; break end
            end

            conf = filters.joinable_quest
            if conf.enabled then
                local available_slots = search_result.maxMemberNum - search_result.memberNum
                local is_npc_only     = (search_result.multiplaySetting == NPC_ONLY)
                if (available_slots == 0) or is_npc_only then should_remove = true; break end
            end
        until true
        if should_remove and not is_contains(quests_to_remove, i) then table.insert(quests_to_remove, i) end
    end

    for index = #quests_to_remove, 1, -1 do
        quest_list:RemoveAt(quests_to_remove[index])
    end
end
    
local SERCH_RESCUE_SIGNAL <const> = sdk.find_type_definition("app.GUI050000.CATEGORY"):get_field("SERCH_RESCUE_SIGNAL"):get_data()
local RECRUITMENT_LOBBY <const>   = sdk.find_type_definition("app.GUI050000.CATEGORY"):get_field("RECRUITMENT_LOBBY"):get_data()
sdk.hook(sdk.find_type_definition("app.GUI050000QuestListParts"):get_method("sortQuestDataList(System.Boolean)"), function(args)
    if not config.enabled then return end
    local quest_list_parts = sdk.to_managed_object(args[2])
    local category         = quest_list_parts:get_field("<ViewCategory>k__BackingField")
    if     (category == SERCH_RESCUE_SIGNAL) and (config.general_filters.enabled or config.item_filters.enabled) then filter_sos_quest_list(quest_list_parts:get_field("<ViewQuestDataList>k__BackingField")) 
    elseif (category == RECRUITMENT_LOBBY)   and config.lobby_member_quest_filters.enabled                       then filter_lobby_member_quest_list(quest_list_parts:get_field("<ViewQuestDataList>k__BackingField")) end
return sdk.PreHookResult.CALL_ORIGINAL end) 

local function draw_settings_checkbox(setting_name, conf)
    local changed, value = imgui.checkbox("##filter_sos_list_" .. setting_name, conf.enabled or false)
    if changed then conf.enabled = value end
    return value
end

local function draw_settings_text_input(setting_name, conf, min, max, default)
    local width = imgui.calc_text_size(tostring(max)).x + 10
    imgui.push_item_width(width)
    local changed, value = imgui.input_text("##filter_sos_list_" .. setting_name, conf.value, default)
    local value = tonumber(value) or default
    if changed and (value >= min) and (value <= max) then conf.value = value end
    imgui.pop_item_width()
    return value
end

local function draw_settings_comparison(setting_name, conf)
    imgui.push_item_width(UI_WIDTH.comparison_types)
    local          current_index    = COMPARISON_TYPE_LOOKUP[conf.comparison] or 1
    local changed, selected_index   = imgui.combo("##filter_sos_list_" .. setting_name, current_index, COMPARISON_TYPE_LIST)
    if changed then conf.comparison = COMPARISON_TYPE_LIST[selected_index] end
    imgui.pop_item_width()
end

local function draw_settings_menu(setting_name, conf, menus, selected_index, is_allow_multi_checked)
    if not imgui.begin_menu(setting_name .. "##menus" .. #menus, true) then return end
    local new_index = nil
    for i, name in ipairs(menus) do
        local is_checked = is_allow_multi_checked and (conf.list[name] == true) or (i == selected_index)
        if imgui.menu_item(get_localized_text(name), nil, is_checked, conf.enabled) then new_index = i end
    end
    cursor_helper.draw_custom_cursor(config.cursor_scale)
    imgui.end_menu()
    return new_index
end

local limit_min        = 0     -- 슬라이더 전체 최소 한계치
local limit_max        = 1000  -- 슬라이더 전체 최대 한계치
local step_size        = 20    -- 조절 스텝 단위
local min_gap          = 40    -- Min과 Max가 서로 붙지 못하게 할 최소 수치 간격
local active_handle    = nil
local slider_width     = 370
local slider_height    = 4
local handle_size      = Vector2f.new(12, 16)
local pre_display_text = nil
local text_size        = 0
local function draw_slider_range_int(id, current_min, current_max)
    if not id then id = "HR" end
    if is_window_open then
        local window_size  = imgui.get_window_size()
              slider_width = window_size.x - 24
    end
    local cursor_pos    = imgui.get_cursor_screen_pos()
          cursor_pos.x  = cursor_pos.x + 10
    local display_text  = string.format("%4d  <  Host " .. id .. "  <  %4d", current_min, current_max)
    if (pre_display_text ~= display_text) then 
        text_size        = imgui.calc_text_size(display_text) 
        pre_display_text = display_text
    end
    local text_center_x = cursor_pos.x + (slider_width / 2) - (text_size.x / 2)
    local saved_cursor  = imgui.get_cursor_pos() 
    imgui.set_cursor_screen_pos(Vector2f.new(text_center_x, cursor_pos.y))
    imgui.text(display_text)
    imgui.spacing()

    local bar_y          = cursor_pos.y + text_size.y + 10
    local bar_start      = Vector2f.new(cursor_pos.x, bar_y)
    local bar_end        = Vector2f.new(cursor_pos.x + slider_width, bar_y)
    local invisible_size = Vector2f.new(slider_width, handle_size.y + 4)
    imgui.set_cursor_screen_pos(Vector2f.new(cursor_pos.x, bar_y - (handle_size.y / 2)))
    imgui.invisible_button("##slider_catcher" .. id, invisible_size)

    local total_range    = limit_max - limit_min
    local min_ratio      = (current_min - limit_min) / total_range
    local max_ratio      = (current_max - limit_min) / total_range
    local min_x          = bar_start.x + (min_ratio * slider_width)
    local max_x          = bar_start.x + (max_ratio * slider_width)
    local mouse_pos      = imgui.get_mouse()
    local mouse_down     = imgui.is_mouse_down(0) 
    local host_hr_enable = config.general_filters.host_hr.enabled

    if host_hr_enable and mouse_down then
        if not active_handle then
            local hit_y_min = bar_start.y - (handle_size.y / 2) - 4
            local hit_y_max = bar_start.y + (handle_size.y / 2) + 4
            
            if (mouse_pos.y >= hit_y_min) and (mouse_pos.y <= hit_y_max) then
                local min_box_left  = min_x
                local min_box_right = min_x + handle_size.x
                local max_box_left  = max_x - handle_size.x
                local max_box_right = max_x
                      min_box_right = min_box_right + 2
                      max_box_left  = max_box_left - 2

                if     (mouse_pos.x >= min_box_left) and (mouse_pos.x <= min_box_right) then active_handle = "MIN" 
                elseif (mouse_pos.x >= max_box_left) and (mouse_pos.x <= max_box_right) then active_handle = "MAX" end
            end
        else
            local target_x       = math.max(bar_start.x, math.min(bar_end.x, mouse_pos.x))
            local raw_val        = limit_min + ((target_x - bar_start.x) / slider_width) * total_range
            local calculated_val = math.floor(raw_val / step_size + 0.5) * step_size

            if     (active_handle == "MIN") then current_min = math.min(calculated_val, current_max - min_gap) 
            elseif (active_handle == "MAX") then current_max = math.max(calculated_val, current_min + min_gap) 
            end
        end
    else
        active_handle = nil 
    end

    local draw_list        = imgui.get_window_draw_list()
    local color_bar        = 0x555555FF
    local color_fill       = host_hr_enable and 0xFFFFFFFF or 0xFF707070
    local color_min_handle = host_hr_enable and 0xFFFFFF00 or 0xFF707070
    local color_max_handle = host_hr_enable and 0xFFFF0000 or 0xFF707070
    local color_black      = 0x000000FF

    draw_list:add_line(bar_start, bar_end, color_bar, slider_height)
    draw_list:add_line(Vector2f.new(min_x, bar_start.y), Vector2f.new(max_x, bar_start.y), color_fill, slider_height)

    local min_top_left  = Vector2f.new(min_x, bar_start.y - (handle_size.y / 2))
    local min_bot_right = Vector2f.new(min_x + handle_size.x, bar_start.y + (handle_size.y / 2))
    draw_list:add_rect_filled(min_top_left, min_bot_right, color_min_handle)
    draw_list:add_rect(Vector2f.new(min_top_left.x + 2, min_top_left.y + 2), Vector2f.new(min_bot_right.x - 2, min_bot_right.y - 2), color_black)

    local max_top_left  = Vector2f.new(max_x - handle_size.x, bar_start.y - (handle_size.y / 2))
    local max_bot_right = Vector2f.new(max_x, bar_start.y + (handle_size.y / 2))
    draw_list:add_rect_filled(max_top_left, max_bot_right, color_max_handle)
    draw_list:add_rect(Vector2f.new(max_top_left.x + 2, max_top_left.y + 2), Vector2f.new(max_bot_right.x - 2, max_bot_right.y - 2), color_black)

    imgui.spacing()
    return current_min, current_max    
end

local function draw_mod_settings()
    imgui.spacing()
    draw_settings_checkbox("enabled", config)
    imgui.same_line()
    imgui.text("Mod")
    imgui.same_line()
    if config.enabled then imgui.text_colored("Enabled",  -16711936)
    else                   imgui.text_colored("Disabled", -16776961) end
    -- General SOS Filters ------------------------------------------------------------------------------------------------------------------------------------
    local filter = config.general_filters
    local conf
    imgui.separator()
    draw_settings_checkbox("general_filters", filter)
    imgui.same_line()
    imgui.text("General SOS Filters")
    imgui.same_line()
    if not filter.enabled then imgui.text_colored("Disabled", -16776961)
    else                       imgui.text_colored("Enabled",  -16711936)
        -- Auto/Manual join approval --------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_join_approval
        draw_settings_checkbox("filter_accept_setting", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.accept_modes)
        local accept_option_index = ACCEPT_MODE_LOOKUP[conf.value] or 1
        local changed, new_index  = imgui.combo("##filter_sos_list_accept_setting", accept_option_index, ACCEPT_MODE_LIST)
        if changed then conf.value = ACCEPT_MODE_LIST[new_index] end
        imgui.pop_item_width()
        imgui.same_line()
        imgui.text("join approval ")
        imgui.end_disabled()
        -- Quest Level ----------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_level
        draw_settings_checkbox("filter_quest_level", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests " .. ((conf.comparison == "exactly") and "at" or "with"))
        imgui.same_line()
        draw_settings_comparison("quest_level_comparison", conf)
        imgui.same_line()
        draw_settings_text_input("quest_level_filter", conf, 1, 10, 8)
        imgui.same_line()
        imgui.text("quest level ")
        imgui.end_disabled() 
        -- Host hunter Rank -----------------------------------------------------------------------------------------------------------------------------------
        conf = filter.host_hr
        draw_settings_checkbox("filter_host_hr", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with host HR limits")
        if conf.enabled then 
            imgui.text(" \u{2515}")
            imgui.same_line(); draw_settings_checkbox("filter_host_hr_threshold", conf.threshold)
            imgui.same_line(); imgui.text("Apply only if quest level is" .. ((conf.threshold.comparison == "exactly") and " at" or ""))
            imgui.same_line(); draw_settings_comparison("host_hr_threshold_comparison", conf.threshold)
            imgui.same_line(); draw_settings_text_input("host_hr_threshold_level_filter", conf.threshold, 1, 10, 8)
        end
        conf.min, conf.max = draw_slider_range_int("HR", conf.min, conf.max)
        imgui.end_disabled()
        -- Monster Name ---------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.monster_name
        draw_settings_checkbox("monster_name", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests matching base name")
        imgui.indent(30)
        local boss_names_str  = nil
        local remaining_count = nil
        for _, name in ipairs(ENEMY_BOSS.NAME_LIST) do
            local id         = ENEMY_BOSS.NAME_MAP[name]
            local is_checked = conf.list[id] and (conf.list[id] == true)
            if is_checked then
                local current_monster_name = ENEMY_BOSS.ID_MAP[id]
                if not remaining_count then
                    local next_str = (boss_names_str and boss_names_str .. ", " or "") .. current_monster_name
                    if (imgui.calc_text_size(next_str).x > 200) then remaining_count = 1
                    else                                             boss_names_str  = next_str end
                else
                    remaining_count = remaining_count + 1
                end
            end
        end
        if     remaining_count                              then boss_names_str = boss_names_str .. " and +" .. tostring(remaining_count) .. " more"
        elseif not boss_names_str or (boss_names_str == "") then boss_names_str = "  <No Monster Name Selected>  "                                   end
        if remaining_count then
            if imgui.button("Reset", { 50, 24 }) then conf.list = {} end
            imgui.same_line()
        end
        imgui.set_next_item_width(280)
        if imgui.begin_menu(boss_names_str .. "##menuName", true) then
            for _, name in ipairs(ENEMY_BOSS.NAME_LIST) do
                local id         = ENEMY_BOSS.NAME_MAP[name]
                local is_checked = conf.list[id] and (conf.list[id] == true)
                if imgui.menu_item(name, nil, is_checked, conf.enabled) then 
                    conf.list[id] = not is_checked 
                end
            end
            cursor_helper.draw_custom_cursor(config.cursor_scale)
            imgui.end_menu()
        end
        imgui.unindent(30)
        imgui.end_disabled()
        -- Monster Species ------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.monster_species
        draw_settings_checkbox("filter_monster_species", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line() 
        imgui.text("Show only quests with")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.enemy_species)
        local changed, new_index = imgui.combo("##filter_monster_species", conf.value, ENEMY_BOSS.SPECIES_MAP)
        if changed then conf.value = new_index end
        imgui.pop_item_width()
        imgui.same_line()
        imgui.text("targets ")
        imgui.end_disabled()
        -- Monster Threat -------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.monster_threat
        draw_settings_checkbox("filter_monster_threat", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests " .. ((conf.comparison == "exactly") and "at" or "with"))
        imgui.same_line()
        draw_settings_comparison("monster_threat_comparison", conf)
        imgui.same_line()
        draw_settings_text_input("monster_threat_filter", conf, 1, 5, 3)
        imgui.same_line()
        imgui.text("threat level ")
        imgui.end_disabled()
        -- Monster Count --------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.monster_count
        draw_settings_checkbox("monster_count", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("monster_count_comparison", conf)
        imgui.same_line()
        local value = draw_settings_text_input("monster_count_filter", conf, 1, 4, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "monster " or "monsters ")
        imgui.end_disabled()
        -- Current Player Count -------------------------------------------------------------------------------------------------------------------------------
        conf = filter.current_players
        draw_settings_checkbox("filter_current_players", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("current_players_comparison", conf)
        imgui.same_line()
        local value = draw_settings_text_input("current_players_filter", conf, 1, 3, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "current player " or "current players ")
        imgui.end_disabled() 
        -- Max Player Count -----------------------------------------------------------------------------------------------------------------------------------
        conf = filter.max_players
        draw_settings_checkbox("filter_max_players", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line() 
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("max_players_comparison", conf)
        imgui.same_line()
        draw_settings_text_input("max_players_filter", conf, 2, 4, 2)
        imgui.same_line()
        imgui.text("max players ")
        imgui.end_disabled()
        -- Started Time ---------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_started_time
        draw_settings_checkbox("filter_started_time", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests started within the last")
        imgui.same_line()
        local value = draw_settings_text_input("started_time_filter", conf, 1, 60, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "minute " or "minutes ")
        imgui.end_disabled()
        -- Multiplay Setting ----------------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_multiplay_setting
        draw_settings_checkbox("filter_multiplay_setting", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests that allow")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.multiplay_types)
        local multiplay_index = MULTIPLAY_TYPE_LOOKUP[conf.value] or 1
        local changed, new_index = imgui.combo("##filter_sos_list_multiplay_setting_filter", multiplay_index, MULTIPLAY_TYPE_LIST)
        imgui.pop_item_width()
        if changed then conf.value = MULTIPLAY_TYPE_LIST[new_index] end
        imgui.end_disabled()
        -- Quest Field Setting --------------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_fields
        draw_settings_checkbox("filter_field", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests in")
        imgui.same_line()
        local field_str       = nil
              remaining_count = nil
        for _, field in ipairs(FIELD_LIST) do
            if conf.list[field] then
                if not remaining_count then 
                    local next_str = (field_str and field_str .. "," or "") .. get_localized_text(field) 
                    if (imgui.calc_text_size(next_str).x > 150) then remaining_count = 1
                    else                                             field_str       = next_str end
                else
                    remaining_count = remaining_count + 1
                end
            end
        end
        if     remaining_count                    then field_str = field_str .. " and +" .. tostring(remaining_count) .. " more"
        elseif not field_str or (field_str == "") then field_str = "<No Fields Selected>"                                        end
        local new_index = draw_settings_menu(field_str, conf, FIELD_LIST, 0, true)
        if new_index then 
            local field      = FIELD_LIST[new_index]
            conf.list[field] = not conf.list[field]
        end
        imgui.end_disabled()
        -- Environment Setting --------------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_environment
        draw_settings_checkbox("filter_environment", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests in")
        imgui.same_line()
        local environments_str = nil
              remaining_count  = nil
        for _, environment in ipairs(ENVIRONMENT_LIST) do
            if conf.list[environment] then
                if not remaining_count then 
                    local next_str = (environments_str and environments_str .. "," or "") .. get_localized_text(environment) 
                    if (imgui.calc_text_size(next_str).x > 150) then remaining_count  = 1
                    else                                             environments_str = next_str end
                else
                    remaining_count = remaining_count + 1
                end
            end
        end
        if     remaining_count                                  then environments_str = environments_str .. " and  +" .. tostring(remaining_count) .. " more"
        elseif not environments_str or (environments_str == "") then environments_str = "<No Environments Selected>"                                           end
        local new_index = draw_settings_menu(environments_str, conf, ENVIRONMENT_LIST, 0, true)
        if new_index then 
            local env      = ENVIRONMENT_LIST[new_index]
            conf.list[env] = not conf.list[env]
        end
        imgui.end_disabled()
        -- Wishlist Monster -----------------------------------------------------------------------------------------------------------------------------------
        conf = filter.wishlist
        draw_settings_checkbox("filter_wishlist", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with wishlisted monster drops ")
        imgui.end_disabled()
    end
    -- Item Filters -------------------------------------------------------------------------------------------------------------------------------------------
    conf = config.item_filters
    draw_settings_checkbox("item_filters_enabled", conf)
    imgui.same_line()
    imgui.text("Bonus Rewards Filters")
    imgui.same_line()

    if not conf.enabled then imgui.text_colored("Disabled", -16776961)
    else                     imgui.text_colored("Enabled",  -16711936)
        imgui.text("Filter Mode:")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.filter_modes)
        local filter_style_index = FILTER_MODE_LOOKUP[conf.mode] or 1
        local changed, new_index = imgui.combo("##item_filter_mode", filter_style_index, FILTER_MODE_LIST)
        if changed then conf.mode = FILTER_MODE_LIST[new_index] end
        imgui.pop_item_width()
        if filter_style_index == 1 then
            local filtering = ITEM_FILTERS.CUSTOM_MODE
                  conf      = conf.custom
            imgui.text("Custom Reward Filters:")
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.custom_mode_operators)
            if not conf.operator then conf.operator = "AND" end
            local custom_list_style_index = filtering.operator_lookup[conf.operator] or 1
            local changed, new_index = imgui.combo("##item_filter_operator", custom_list_style_index, filtering.operators)
            if changed then conf.operator = filtering.operators[new_index] end
            imgui.pop_item_width()
            imgui.text("Show SOS quests where")
            for item_id, item_num in pairs(conf.target_list) do
                if item_num then
                    if imgui.button("-##item_filter_Remove_" .. item_id, { 24, 24 }) then 
                        conf.target_list[item_id] = false -- tgaprk
                        filtering.update()
                    end
                    imgui.same_line()
                    imgui.text(get_localized_text(tonumber(item_id) or item_id))
                    imgui.same_line()
                    imgui.text("appears at least")
                    imgui.same_line()
                    imgui.push_item_width(30)
                    local changed, value = imgui.input_text("##item_filter_" .. item_id .. "_Amount", item_num, 1)
                    local value = tonumber(value) or 1
                    if changed and (value >= 1) and (value <= 99) then conf.target_list[item_id] = value end
                    imgui.pop_item_width()
                    imgui.same_line()
                    imgui.text((value == 1) and "time" or "times")
                    imgui.indent(30)
                    imgui.text(conf.operator)
                    imgui.unindent(30)
                end
            end
            imgui.same_line()
            imgui.text("..?")
            if (#filtering.list > 0) then
                if imgui.button("+##item_filter_Add", { 24, 24 }) and (filtering.selected_index > 0) then
                    local selected_item_id = filtering.lookup[filtering.selected_index]
                    conf.target_list[selected_item_id] = 1
                    filtering.update()
                end
            else
                imgui.invisible_button("#item_filter_Invisible_button", { 24, 24 })
            end
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.localized_items)
            local item_name    = filtering.list[filtering.selected_index]
            local selected_str = item_name and get_localized_text(item_name) or "<No more items can be selected>"
            local new_index    = draw_settings_menu(selected_str, conf, filtering.list, item_name and filtering.selected_index or 0, false)
            if new_index then filtering.selected_index = new_index end
            imgui.pop_item_width()
        else
            local filtering = ITEM_FILTERS.MAX_QUANTITY
                  conf      = conf.max_quantity
            imgui.text("Highest Quantity of ")
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.localized_items)
            local selected_index = filtering.lookup[conf.target_item] or 1
            local selected_str   = get_localized_text(filtering.list[selected_index]) or "<No Item Selected> "
            local new_index      = draw_settings_menu(selected_str, filtering, filtering.list, selected_index, false)
            if new_index then conf.target_item = ITEM_NAME_MAP[filtering.list[new_index]] end
            imgui.pop_item_width()
        end
    end
    -- Lobby Member Quest Filters -----------------------------------------------------------------------------------------------------------------------------
    filter = config.lobby_member_quest_filters
    imgui.separator()
    draw_settings_checkbox("general_lobby_member_filters", filter)
    imgui.same_line()
    imgui.text("Lobby Member Quest Filters")
    imgui.same_line()
    if not filter.enabled then imgui.text_colored("Disabled", -16776961)
    else                       imgui.text_colored("Enabled",  -16711936)
        -- without a password ---------------------------------------------------------------------------------------------------------------------------------
        conf = filter.without_password
        draw_settings_checkbox("filter_lobby_member_quest_without_password", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests without a password")
        imgui.end_disabled()
        -- Auto/Manual join approval --------------------------------------------------------------------------------------------------------------------------
        conf = filter.quest_join_approval
        draw_settings_checkbox("filter_lobby_member_quest_accept_setting", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with ")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.accept_modes)
        local accept_option_index = ACCEPT_MODE_LOOKUP[conf.value] or 1
        local changed, new_index  = imgui.combo("##filter_lobby_member_quest_list_accept_setting", accept_option_index, ACCEPT_MODE_LIST)
        if changed then conf.value = ACCEPT_MODE_LIST[new_index] end
        imgui.pop_item_width()
        imgui.same_line()
        imgui.text("join approval ")
        imgui.end_disabled()
        -- available slots ----------------------------------------------------------------------------------------------------------------------------------------
        conf = filter.joinable_quest
        draw_settings_checkbox("filter_lobby_member_quest_joinable_quest", conf)
        imgui.begin_disabled(not conf.enabled)
        imgui.same_line()
        imgui.text("Show only quests with available slots")
        imgui.end_disabled()
    end
    -- Mouse Cursor -------------------------------------------------------------------------------------------------------------------------------------------
    if not cursor_helper.failed_require then
        imgui.separator()
        imgui.spacing()
        imgui.indent(50)
        imgui.push_item_width(300)
        local changed, value = imgui.slider_float("##CursorScale", config.cursor_scale, 0.5, 5, "Cursor scale:  x%.1f")
        if changed then config.cursor_scale = math.floor((value + 0.05) * 10) / 10 end
        imgui.pop_item_width()
        imgui.unindent(50)
    end
    imgui.spacing();imgui.spacing();imgui.spacing()
    cursor_helper.draw_custom_cursor(config.cursor_scale)
end

local function open_mod_settings_window()
    is_window_open = true
    save_config()
end

local function close_mod_settings_window()
    is_window_open = false
    save_config()
end

re.on_frame(function() 
    if not is_window_open or not imgui.begin_window(MOD_TITLE, nil, 120) then return end  -- 8:NoScrollBar, 16:NoScrollWithMouse, 32:NoCollapse, 64:AlwaysAutoResize
    draw_mod_settings()
    imgui.end_window() 
end)

sdk.hook(sdk.find_type_definition("app.GUI050000"):get_method("setQuestListInCategory(app.GUI050000.CATEGORY)"), function(args)
    local category = sdk.to_int64(args[3])
    if (category == SERCH_RESCUE_SIGNAL) or (category == RECRUITMENT_LOBBY) then  open_mod_settings_window()
    else                                                                         close_mod_settings_window() end
return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.GUI050000"):get_method("closeQuestDetailWindow()"),               function(args) close_mod_settings_window() return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.cGUI050000ViewFlow.Flow.RescueSetting"):get_method("onEnter()"),  function(args)  open_mod_settings_window() return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.cGUI050000ViewFlow.Flow.RescueSetting"):get_method("nextFlow()"), function(args) close_mod_settings_window() return sdk.PreHookResult.CALL_ORIGINAL end)

re.on_config_save(save_config)
re.on_draw_ui(function()
	if imgui.tree_node("Filter SOS List##filter_sos_list_config") then
        if is_window_open then
            imgui.text_colored("The dedicated menu is now active.", 0xFF00FFFF)
            imgui.text_colored("Please use the in-game window.",    0xFFFFFFFF)
        else
		    draw_mod_settings()
        end
        imgui.tree_pop()
	end
end)
