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
local create_guid_string   = function(guid_obj) return guid_obj and string.format("%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x", guid_obj.mData1, guid_obj.mData2, guid_obj.mData3, guid_obj.mData4_0, guid_obj.mData4_1, guid_obj.mData4_2, guid_obj.mData4_3, guid_obj.mData4_4, guid_obj.mData4_5, guid_obj.mData4_6, guid_obj.mData4_7) end
local system_guid_cache    = {}
local function get_system_guid(guid_string)
    if not guid_string then return nil end
    local guid = system_guid_cache[guid_string]
    if not guid then
        guid                           = create_system_guid(guid_string)
        system_guid_cache[guid_string] = guid
    end
    return guid
end

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
        max_players = {
            enabled    = false,
            value      = 4,
            comparison = "at most",
        },
        current_players = {
            enabled    = false,
            value      = 1,
            comparison = "at least",
        },
        blocked_users = {
            enabled = false,
        },
        wishlist = {
            enabled = false,
        },        
        quest_join_approval = {
            enabled = true,
            value   = "Auto-accept",
        },
        quest_started_time = {
            enabled = false,
            value = 1,
        },
        quest_multiplay_setting = {
            enabled = false,
            value   = "Players & Support Hunters",
        },
        quest_fields = {
            enabled = false,
            list    = { ["Plains"] = false, ["Forest"] = false, ["Basin"] = false, ["Cliffs"] = false, ["Wyveria"] = false, ["Wounded Hollow"] = false, ["Rimechain Peak"] = false, ["Dragontorch Shrine"] = false, ["Forgotten Machineworks"] = false },
        },
        quest_environment  = {
            enabled = false,
            list    = { ["Plenty"] = false, ["Fallow"] = false, ["Inclemency"] = false }
        },
        mission_type = {
            enabled = false,
            value   = 0,
            list    = { ["Assignments"] = false, ["Optional Quests"] = false, ["Investigations"] = false, ["Event Quests"] = false },
        },
        gathering_boost = {
            enabled = false,
        },
        limit_weapon = {
            enabled = false,
            reserve = { enabled = false },
            list    = { ["Great Sword"] = false, ["Sword & Shield"] = false, ["Dual Blades"] = false, ["Long Sword"] = false, ["Hammer"] = false, ["Hunting Horn"] = false, ["Lance"] = false, ["Gunlance"] = false, ["Switch Axe"] = false, ["Charge Blade"] = false, ["Insect Glaive"] = false, ["Bow"] = false, ["Heavy Bowgun"] = false, ["Light Bowgun"] = false }
        },
    },
    item_filters = {
        enabled = false,
        mode    = "Custom",
        custom = {
            operator    = "AND",
            target_list = { ["469"] = false, ["470"] = false, ["478"] = false, ["157"] = false, ["620"] = false, ["653"] = false, ["820"] = false, ["WISHLIST"] = false, ["GEM"] = false, }, -- ["item_id"] = number or false
        },
        max_quantity = {
            target_item = "469",
        },
        target_reward_filter = {
            target_item = "469",
        }
    },
    lobby_member_quest_filters = {
        enabled = false,
        without_password = {
            enabled = false
        },
        quest_join_approval = {
            enabled = false,
            value   = "Auto-accept",
        },
        joinable_quest = {
            enabled = false,
        },
        blocked_users = {
            enabled = false,
        },
        sos_flare_active = {
            enabled = false,
        },
    },
    keep_searching = {
        enabled = false,
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
    ["at least"] = function(current, required) return (current >= required) end,
    ["at most"]  = function(current, required) return (current <= required) end,
    ["exactly"]  = function(current, required) return (current == required) end,
}

local MULTIPLAY_TYPE_LIST <const>   = {  "Players & Support Hunters",       "Only Players" }
local MULTIPLAY_TYPE_LOOKUP <const> = { ["Players & Support Hunters"] = 1, ["Only Players"] = 2 }

local FILTER_MODE_LIST <const>   = {  "Custom",       "Max Quantity",       "Target Reward Filter" }
local FILTER_MODE_LOOKUP <const> = { ["Custom"] = 1, ["Max Quantity"] = 2, ["Target Reward Filter"] = 3 }

local FIELD_LIST <const>   = {       "Plains",       "Forest",       "Basin",       "Cliffs",       "Wyveria",       "Wounded Hollow",        "Rimechain Peak",        "Dragontorch Shrine",        "Forgotten Machineworks" }
local FIELD_ID_MAP <const> = { [0] = "Plains", [1] = "Forest", [2] = "Basin", [3] = "Cliffs", [4] = "Wyveria", [9] = "Wounded Hollow", [10] = "Rimechain Peak", [11] = "Dragontorch Shrine", [13] = "Forgotten Machineworks" }

local ENVIRONMENT_LIST <const>    = {       "Plenty",       "Fallow",       "Inclemency" }
local ENVIRONMENT_ID_MAP <const>  = { [2] = "Plenty", [0] = "Fallow", [1] = "Inclemency" }

local ACCEPT_MODE_LIST <const>   = {  "Auto-accept",          "Manual Accept" }
local ACCEPT_MODE_LOOKUP <const> = { ["Auto-accept"] = 1,    ["Manual Accept"] = 2 }
local is_auto_accept <const>     = { ["Auto-accept"] = true, ["Manual Accept"] = false, ["Auto"] = true, ["Manula"] = false }

local MISSION_TYPE_LIST <const>   = {       "Assignments",                            "Optional Quests",       "Investigations",                               "Event Quests" }
local MISSION_TYPE_ID_MAP <const> = { [0] = "Assignments", [1] = "Assignments", [2] = "Optional Quests", [4] = "Investigations", [5] = "Investigations", [6] = "Event Quests" }

local QUEST_TYPE_LIST <const>   = {       "Hunting",       "Kill",       "Capture",       "Collects",       "Transport",       "Arena",       "Bossrush",       "Special" }
local QUEST_TYPE_ID_MAP <const> = { [0] = "Hunting", [1] = "Kill", [2] = "Capture", [3] = "Collects", [4] = "Transport", [5] = "Arena", [6] = "Bossrush", [7] = "Special" }

local WEAPON_LIST <const>   = {       "Great Sword",       "Sword & Shield",       "Dual Blades",       "Long Sword",       "Hammer",       "Hunting Horn",       "Lance",       "Gunlance",       "Switch Axe",       "Charge Blade",        "Insect Glaive",        "Bow",        "Heavy Bowgun",        "Light Bowgun" }
local WEAPON_ID_MAP <const> = { [0] = "Great Sword", [1] = "Sword & Shield", [2] = "Dual Blades", [3] = "Long Sword", [4] = "Hammer", [5] = "Hunting Horn", [6] = "Lance", [7] = "Gunlance", [8] = "Switch Axe", [9] = "Charge Blade", [10] = "Insect Glaive", [11] = "Bow", [12] = "Heavy Bowgun", [13] = "Light Bowgun" }

local NPC_ONLY <const>            = sdk.find_type_definition("app.net_quest_session.cCreateQuestSessionInfo.MULTIPLAY_SETTING"):get_field("NPC_ONLY"):get_data() or 2
local SERCH_RESCUE_SIGNAL <const> = sdk.find_type_definition("app.GUI050000.CATEGORY"):get_field("SERCH_RESCUE_SIGNAL"):get_data()
local RECRUITMENT_LOBBY <const>   = sdk.find_type_definition("app.GUI050000.CATEGORY"):get_field("RECRUITMENT_LOBBY"):get_data()

local LOCALIZED_TEXT = {
    MAP = {},
    MULTIPLAY_TYPES = {},
    ACCEPT_MODE = {},
}
local GUID_MAP <const>   = {
    ["Plains"]                    = "e232918e-ee5a-4723-9618-ad8799eb8dc1",
    ["Forest"]                    = "ce61d1bb-48ba-4256-b321-a98c7699abd0",
    ["Basin"]                     = "7cd70789-f7e1-439f-adb5-dcc84155329c",
    ["Cliffs"]                    = "05c57b50-8a37-45d8-8270-d0b7d9e26d41",
    ["Wyveria"]                   = "edf6ca79-4396-4fc2-a9bf-ecddbb41020f",
    ["Wounded Hollow"]            = "96c9fa8f-0ac2-4351-a636-363fef236722",
    ["Rimechain Peak"]            = "bf7c1e0b-41ef-4a42-bbdb-b8cbb56089fa",
    ["Dragontorch Shrine"]        = "e1d6d887-5bb9-4246-b08c-eb540a49947f",
    ["Forgotten Machineworks"]    = "8c000ff9-6104-47c4-a616-af6a7510b6fd",
    ["Plenty"]                    = "1652ff9a-674d-4432-a348-25c28375602a", -- 풍요기
    ["Fallow"]                    = "4756804f-e6cb-4b8f-8f87-7357b0087c76", -- 황폐기
    ["Inclemency"]                = "7b5b392e-4e61-4f21-9ad6-9b50711d879c", -- 기상 이변
    ["Frostwinds"]                = "d68c3291-b596-461e-a0a1-349803c0a624", -- 눈보라
    ["Downpour"]                  = "e0de3c96-94e6-446f-9069-aec17647567e", -- 집중 호우
    ["Sandtide"]                  = "7f8e18c7-dfbd-43df-96db-340f0f902da9", -- 모래 폭풍
    ["Assignments"]               = "e284bb17-5832-4884-9e97-b27935d895cd", -- 임무 퀘스트
    ["Optional Quests"]           = "2092b44c-6ca1-4739-8c15-de9ff059bf1f", -- 자유 퀘스트
    ["Investigations"]            = "6a5c2dbb-e2ac-4c14-8dce-9f2cc7845e9e", -- 조사 퀘스트
    ["Event Quests"]              = "85173188-e304-4770-bf5f-a31f44001ee3", -- 이벤트 퀘스트
    ["Challenge Quests"]          = "3e7f2b1c-6558-4378-87ef-54c5ad20b4c6", -- 챌린지 퀘스트
    ["Free Challenge Quests"]     = "c7881ddd-164d-4ece-ad22-46bd6029ee5a", -- 프리 챌린지 퀘스트
    ["Arena Quests"]              = "b9a42b39-a410-4aa8-9c0f-f869d810c93e", -- 격투대회 퀘스트
    ["All Quests"]                = "c089ea63-5a87-49d4-a553-b23173521043", -- 모든 퀘스트
    ["Any"]                       = "8fee14a2-10f0-41a2-8c40-72a029623bbc", -- 지정 없음
    ["SOS Flare Quests"]          = "d22d376c-e3df-413e-92ff-0a28be9ab6e8",
    ["Bonus Rewards"]             = "346221cc-93a1-43d8-8f74-ae437c2ea9c8",
    ["Lobby Member Quests"]       = "4f2f9156-b1ae-4f76-bc6e-274b4d0e163b",
    ["Great Sword"]               = "7c666d48-f75d-4d29-99d3-8ae10938d756",
    ["Sword & Shield"]            = "e757291a-478a-4206-8e61-2831732ee767",
    ["Dual Blades"]               = "5df72c46-ccf7-4a74-86fd-528a3de404d4",
    ["Long Sword"]                = "a8d7c0e5-bd89-4fff-9635-19d41b3a5918",
    ["Hammer"]                    = "744ba34b-307a-478c-b099-35af9d8a5e8f",
    ["Hunting Horn"]              = "b7fe4885-237b-41ce-94f2-95c596398cfc",
    ["Lance"]                     = "b835789c-ea15-47d1-886c-91439e661418",
    ["Gunlance"]                  = "0c474220-8d71-443b-8dca-f4aa007e29b9",
    ["Switch Axe"]                = "b1048d25-68dd-48c3-9136-bbd8ee44f2ef",
    ["Charge Blade"]              = "e9fbacb9-386f-4c9b-b084-7827d42301ad",
    ["Insect Glaive"]             = "204eafea-efcc-487e-ba57-b488dcbd91f9",
    ["Bow"]                       = "e69753e3-a107-4a2e-bd8f-76dbe07efffe",
    ["Heavy Bowgun"]              = "fef6ef0a-6cdb-40c6-a3b4-0c0a5c4b284c",
    ["Light Bowgun"]              = "a664bfb1-a953-4adf-80f3-582e464be294",
    ["High Rank"]                 = "5238ed96-3c55-402c-8f7a-088df7077136", -- 상위
    ["Low Rank"]                  = "35fbf6f0-8536-4319-a6d7-3f5dce0b1053", -- 하위
    ["Hunting"]                   = "88baa0c8-ecc8-434b-8bf2-e860a12aab69", -- 사냥
    ["Capture"]                   = "bb0174eb-5e48-4d32-a1b5-d9ae5b9e0ffc", -- 포획
    ["Slaying"]                   = "151de205-ff53-483d-bc1c-ce4ca1599d04", -- 토벌
    ["Transport"]                 = "e1df9ca2-83d2-4b07-bfa4-ebccffcfe1e5", -- 운반
    ["Special"]                   = "45fb167b-dd18-4d64-9e72-77aae2bbeed0", -- 특수
    ["Players & Support Hunters"] = "62839405-8576-472c-b13e-68f1db6fdb42",
    ["Only Players"]              = "2ecc4714-89a1-427f-a444-459e52aa98dd",
    ["Auto-accept"]               = "1979acd2-c49a-4f58-b70e-b01105e00aaa",
    ["Manual Accept"]             = "b21e9a7e-5870-4d50-98db-25a6e25f3c80",
    ["gathering boost"]           = "47e87983-6e7c-44dd-b3b2-f1cac33cd4a2",
}

local function get_localized_text(key)
    local text = LOCALIZED_TEXT.MAP[key]
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

        LOCALIZED_TEXT.MAP[ITEM_ID_MAP[tostring(key)]] = text    
    end

    LOCALIZED_TEXT.MAP[key] = text
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
            local species_fixed = get_em_species_fixed:call(nil, id)
            if (species_fixed == ENEMY_BOSS.INVALID_SPECIES) then break end

            local specics_data  = get_em_species_data:call(nil, species_fixed - 1)
            local guid_specics  = specics_data:get_EmSpeciesName()
            local guid_name     = get_em_name:call(nil, id)
            local name          = convert_guid_to_text:call(nil, guid_name, 0)
            local specics_type  = convert_guid_to_text:call(nil, guid_specics, 0)
            local size_x        = imgui.calc_text_size(specics_type).x
            if (size_x > width) then width = size_x end
            id                                    = tostring(id)
            ENEMY_BOSS.NAME_MAP[name]             = id
            ENEMY_BOSS.ID_MAP[id]                 = name
            ENEMY_BOSS.SPECIES_MAP[species_fixed] = specics_type
            table.insert(ENEMY_BOSS.NAME_LIST, name)
            if (conf_name_list[id] == nil) then conf_name_list[id] = false end
        until true
    end
    return (width + 30)
end

local function setup_localized_text()
    LOCALIZED_TEXT.MULTIPLAY_TYPES = {}
    for _, text in ipairs(MULTIPLAY_TYPE_LIST) do 
        table.insert(LOCALIZED_TEXT.MULTIPLAY_TYPES, get_localized_text(text))
    end
    LOCALIZED_TEXT.ACCEPT_MODE = {}
    for _, text in ipairs(ACCEPT_MODE_LIST) do 
        table.insert(LOCALIZED_TEXT.ACCEPT_MODE, get_localized_text(text))
    end
end

local ITEM_FILTERS ={
    REQUIRED_REWARDS = {
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

local UI_TEXT_SIZE = {}
local UI_WIDTH     = {
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
    for i, text in pairs(LOCALIZED_TEXT.MULTIPLAY_TYPES) do 
        local size = imgui.calc_text_size(text).x
        if (size > width) then width = size end
    end
    UI_WIDTH.multiplay_types = width + 30

    width = 0
    for i, text in pairs(LOCALIZED_TEXT.ACCEPT_MODE) do 
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
re.on_config_save(save_config)

local function load_config()
    if old_config then return end
    local loaded = json.load_file(CONFIG_FILE)
    if not loaded then save_config(true) return end 
    if (type(loaded) == "table") then merge_config(config, loaded) end
    old_config = array_deep_copy(config)
end 

local function initialize()  
    LOCALIZED_TEXT.MAP     = {}  -- 옵션의 문자 언어 설정 변경하는 경우를 대비해서 항상 초기화한다.
    UI_WIDTH.enemy_species = ENEMY_BOSS.update()

    load_config()
    setup_localized_text()
    UI_WIDTH.update()
    ITEM_FILTERS.CUSTOM_MODE.update()
end initialize()
sdk.hook(sdk.find_type_definition("app.GUI020001"):get_method(".ctor()"), function(args) initialize() end) 

local network_manager     = sdk.get_managed_singleton("app.NetworkManager")
local context_manager     = network_manager:get_ContextManager()
local player_platform_id  = context_manager:get_PlatformId()
local block_list_service  = network_manager:get_BlockListService()
local reward_util         = sdk.find_type_definition("app.ExQuestRewardUtil")
local export_rewards      = reward_util:get_method("exportExRewardInfoToItemWorkList(app.cExEnemyRewardItemInfo)")
local wishlist_util       = sdk.find_type_definition("app.WishlistUtil")
local is_wishlist_item    = wishlist_util:get_method("isItemRequiredForWishlist(app.ItemDef.ID)")
local is_wishlist_quest   = wishlist_util:get_method("isExQuestRequiredForWishlist(app.cExEnemyRewardItemInfo, app.EnemyDef.ID[], app.EnemyDef.ROLE_ID[], app.EnemyDef.LEGENDARY_ID[], app.QuestDef.RANK, app.QuestDef.EM_REWARD_RANK[], System.Boolean)") 
local is_wishlist_mission = wishlist_util:get_method("isQuestRequiredForWishlist(app.MissionIDList.ID, app.QuestDef.RANK)")
local filter_order = {
    "quest_join_approval",
    "blocked_users",
    "joinable_quest",
    "without_password",
    "sos_flare_active",
    "monster_species",
    "quest_level",
    "host_hr",
    "quest_started_time",
    "quest_multiplay_setting",
    "mission_type",
    "gathering_boost",
    "wishlist",
    "monster_name",
    "monster_count",
    "monster_threat",
    "current_players",
    "max_players",
    "limit_weapon",
    "quest_fields",
    "quest_environment",
    "item_reward_custom",
}

local filter_methods = { -- return true if the quest should be filtered out (removed) from the list
    ["quest_join_approval"] = function(quest_data, filter) 
        local session_data = quest_data.Session  -- app.cGUIQuestViewData.cGUISessionData
        return (is_auto_accept[filter.value] ~= session_data:get_isAutoAccept())
    end,
    ["quest_started_time"] = function(quest_data, filter) 
        local session_data         = quest_data.Session
        local started_at           = session_data:get_StartTime()
              started_at           = (started_at > 0) and started_at or session_data:get_AcceptedTime()
        local started_difference   = (os.time() - started_at) / 60
        return (started_difference >= filter.value)
    end,
    ["quest_multiplay_setting"] = function(quest_data, filter) 
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()  -- app.net_session_manager.SessionManager.cSearchResultQuest
        return (search_result.multiplaySetting ~= (MULTIPLAY_TYPE_LOOKUP[filter.value] - 1))
    end,
    ["quest_fields"] = function(quest_data, filter) 
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()
        local field         = FIELD_ID_MAP[search_result.fieldId]
        return not filter.list[field]
    end,
    ["quest_environment"] = function(quest_data, filter) 
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()
        local environment   = ENVIRONMENT_ID_MAP[search_result.envType]
        return not filter.list[environment]
    end,
    ["blocked_users"] = function(quest_data, filter) 
        local session_data = quest_data.Session
        local user_ids     = session_data:getQuestMembersUserId()
        local length       = user_ids:get_size()
        for j = 0, length - 1 do
            local user_id     = user_ids:get_Item(j)
            local guid_string = create_guid_string(user_id)
            local guid        = get_system_guid(guid_string)
            if guid and block_list_service:isBlock(guid) then return true end
        end
        return false
    end,
    ["wishlist"] = function(quest_data, filter) 
        local is_quest_wishlisted = false
        local session_data        = quest_data.Session
        local search_result       = session_data:get_SearchResult()
        local active_quest        = quest_data:get_ActiveQuestData()
        local quest_rank          = search_result.questRank           -- app.QuestDef.RANK
        if active_quest then
            local mission_id = active_quest:get_MissionId()
            if (mission_id ~= -1) then is_quest_wishlisted = is_wishlist_mission:call(wishlist_util, mission_id, quest_rank) end
        end
        if not is_quest_wishlisted then
            local quest_reward_obj    = quest_data:get_ExEnemyRewardItemInfo()  -- app.cExEnemyRewardItemInfo get_ExEnemyRewardItemInfo()
            local monster_ids         = quest_data:get_TargetEmId()             -- app.EnemyDef.ID[] get_TargetEmId()
            local quest_role_ids      = quest_data:get_TargetEmRoleId()         -- app.EnemyDef.ROLE_ID[] get_TargetEmRoleId()
            local quest_legendary_ids = quest_data:get_TargetEmLegendaryId()    -- app.EnemyDef.LEGENDARY_ID[] get_TargetEmLegendaryId()
            local quest_reward_ranks  = quest_data:getTargetEmRewardRank()      -- app.QuestDef.EM_REWARD_RANK[]
                  is_quest_wishlisted = is_wishlist_quest:call(wishlist_util, quest_reward_obj, monster_ids, quest_role_ids, quest_legendary_ids, quest_rank, quest_reward_ranks, true) 
        end
        return not is_quest_wishlisted
    end,
    ["monster_name"] = function(quest_data, filter) 
        local monster_ids   = quest_data:get_TargetEmId()      -- app.EnemyDef.ID[] get_TargetEmId()
        local monster_count = monster_ids:get_size()
        for k = 0, monster_count - 1 do 
            local em_id = monster_ids:get_Item(k)
            if filter.list[tostring(em_id)] then return false end
        end
        return true
    end,
    ["monster_count"] = function(quest_data, filter) 
        local monster_ids   = quest_data:get_TargetEmId()      -- app.EnemyDef.ID[] get_TargetEmId()
        local monster_count = monster_ids:get_size()
        local comparison    = filter.comparison or COMPARISON_TYPE_LIST[1]
        local evaluator     = EVALUATORS[comparison]
        return not (evaluator and evaluator(monster_count, filter.value))
    end,
    ["monster_threat"] = function(quest_data, filter) 
        local monster_difficulties       = quest_data:getTragetEmDifficulityRank()  -- 게임 API 자체 오타였다
        local monster_difficulties_count = monster_difficulties:get_size()
        local comparison                 = filter.comparison or COMPARISON_TYPE_LIST[1]
        local evaluator                  = EVALUATORS[comparison]
        for diff_index = 0, monster_difficulties_count - 1 do
            local monster_difficulty = monster_difficulties:get_Item(diff_index)
            if evaluator and evaluator(monster_difficulty, filter.value) then return false end
        end
        return true
    end,
    ["quest_level"] = function(quest_data, filter) 
        local quest_level = quest_data:get_QuestLv()
        local comparison  = filter.comparison or COMPARISON_TYPE_LIST[1]
        local evaluator   = EVALUATORS[comparison]
        return not (evaluator and evaluator(quest_level, filter.value))
    end,
    ["host_hr"] = function(quest_data, filter) 
        local session_data = quest_data.Session
        local host_hr      = session_data:get_HostHr()
        local min, max     = filter.min, filter.max
        local need_check   = true
        local threshold    = filter.threshold
        if threshold.enabled then
            local comparison = threshold.comparison or COMPARISON_TYPE_LIST[1]
            local evaluator  = EVALUATORS[comparison]
            if not (evaluator and evaluator(quest_data:get_QuestLv(), threshold.value)) then need_check = false end
        end
        return need_check and ((host_hr <= min) or (host_hr >= max))
    end,
    ["monster_species"] = function(quest_data, filter) 
        local monster_ids   = quest_data:get_TargetEmId()      -- app.EnemyDef.ID[] get_TargetEmId()
        local monster_count = monster_ids:get_size()
        for k = 0, monster_count - 1 do 
            local species_fixed = get_em_species_fixed:call(nil, monster_ids:get_Item(k))
            if (species_fixed == filter.value) then return false end
        end
        return true
    end,
    ["current_players"] = function(quest_data, filter) 
        local session_data    = quest_data.Session
        local current_players = session_data:get_MemberNum()
        local comparison      = filter.comparison or COMPARISON_TYPE_LIST[3]
        local evaluator       = EVALUATORS[comparison]
        return not (evaluator and evaluator(current_players, filter.value))
    end,
    ["max_players"] = function(quest_data, filter) 
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()
        local max_players   = search_result.maxMemberNum
        local comparison    = filter.comparison or COMPARISON_TYPE_LIST[2]
        local evaluator     = EVALUATORS[comparison]
        return not (evaluator and evaluator(max_players, filter.value))
    end,
    ["joinable_quest"] = function(quest_data, filter) 
        local session_data = quest_data.Session
        local is_full = (session_data:get_MemberMax() == session_data:get_MemberNum())
        if is_full then return true end
        local search_result = session_data:get_SearchResult() 
        if (search_result.multiplaySetting == NPC_ONLY) then return true end
        if search_result.isSamePlatform then 
            local host_info = search_result:getHostHunterInfo()
            if (host_info.platformId ~= player_platform_id) then return true end
        end
        return false
    end,
    ["without_password"] = function(quest_data, filter) 
        local session_data = quest_data.Session
        return session_data:get_IsNeedPassword()
    end,
    ["sos_flare_active"] = function(quest_data, filter)
        local session_data = quest_data.Session
        return session_data:get_IsResucue()
    end,
    ["mission_type"] = function(quest_data, filter)
        local session_data     = quest_data.Session
        local search_result    = session_data:get_SearchResult()
        local mission_type     = search_result:getMissionType()  -- app.MissionTypeList.TYPE,  MAINSTORY:0, SIDESTORY:1, FREEQUEST:2, KEEPQUEST:4, INSTANTQUEST:5, STREAM_EVENTQUEST:6
        local mission_type_str = MISSION_TYPE_ID_MAP[mission_type]
        return not filter.list[mission_type_str]
    end,
    ["quest_type"] = function(quest_data, filter)
        local session_data = quest_data.Session
        local quest_type   = session_data:get_QuestType() -- app.QuestDef.QUEST_TYPE, HUNTING = 0, KILL = 1, CAPTURE = 2, COLLECTS = 3, TRANSPORT = 4, ARENA = 5, BOSSRUSH = 6, SPECIAL = 7
        return (quest_type ~= filter.value)
    end,
    ["quest_life"] = function(quest_data, filter)
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()
        local quest_life    = search_result.questLife
        local comparison    = filter.comparison or COMPARISON_TYPE_LIST[1]
        local evaluator     = EVALUATORS[comparison]
        return not (evaluator and evaluator(quest_life, filter.value))
    end,
    ["gathering_boost"] = function(quest_data, filter)
        local session_data  = quest_data.Session
        local search_result = session_data:get_SearchResult()
        return not search_result.isBoost
    end,
    ["limit_weapon"] = function(quest_data, filter)
        local session_data    = quest_data.Session
        local main_weapons    = session_data:get_MainWeaponType() -- app.WeaponDef.TYPE[]
        local reserve_weapons = session_data:get_ReserveWeaponType() 
        local is_target       = filter.list
        local found           = false
        for i = 0, (main_weapons:get_size() - 1) do 
            local main_wp        = main_weapons[i].value__
            local reserve_wp     = reserve_weapons[i].value__
            local main_weapon    = WEAPON_ID_MAP[main_wp]
            local reserve_weapon = WEAPON_ID_MAP[reserve_wp]
            if (is_target[main_weapon] or (filter.reserve.enabled and is_target[reserve_weapon])) then found = true; break end
        end
        return found
    end,
    ["item_reward_custom"] = function(quest_data, filter)
        local reward_table     = {}
        local quest_reward_obj = quest_data:get_ExEnemyRewardItemInfo()  -- app.cExEnemyRewardItemInfo get_ExEnemyRewardItemInfo()
        local item_work_list   = export_rewards:call(reward_util, quest_reward_obj)
        for item_i = 0, item_work_list._size - 1 do
            local item_work                = item_work_list:get_Item(item_i)
            local item_id                  = tostring(item_work:get_ItemId())
            local item_num                 = item_work.Num or 0
            local quest_reward_on_wishlist = is_wishlist_item:call(wishlist_util, tonumber(item_id))
            if quest_reward_on_wishlist          then reward_table["WISHLIST"] = (reward_table["WISHLIST"] and reward_table["WISHLIST"] or 0) + item_num end
            if is_contains(GEM_ID_LIST, item_id) then item_id                  = "GEM"                                                                   end
            reward_table[item_id] = (reward_table[item_id] and reward_table[item_id] or 0) + item_num
        end

        local is_logical_or = (filter.custom.operator == "OR")
        local target_list   = filter.custom.target_list
        for item_id, min_required in pairs(target_list) do
            if min_required then
                local amount = reward_table[item_id] or 0
                if (amount >= min_required) then if     is_logical_or then return false end 
                else                             if not is_logical_or then return true  end end
            end
        end
        return is_logical_or
    end,
    ["item_reward_max_quantity"] = function(quest_list, target_item)
        if not quest_list then return end

        local quest_list_size = quest_list:get_Count()
        if quest_list_size == 0 then return end 

        local max_quantity = 0
        for i = (quest_list_size - 1), 0, -1 do
            repeat
                local quest_data = quest_list:get_Item(i)
                if not quest_data then break end

                local target_item_count = 0
                local quest_reward_obj  = quest_data:get_ExEnemyRewardItemInfo()  -- app.cExEnemyRewardItemInfo get_ExEnemyRewardItemInfo()
                local item_work_list    = export_rewards:call(reward_util, quest_reward_obj)
                for item_i = 0, item_work_list._size - 1 do
                    local item_work = item_work_list:get_Item(item_i)
                    local item_id   = tostring(item_work:get_ItemId())
                    if (item_id == target_item) then 
                        local item_num  = item_work.Num or 0
                        target_item_count = target_item_count + item_num
                    end
                end
                if     (target_item_count < max_quantity) then quest_list:RemoveAt(i)           break 
                elseif (target_item_count > max_quantity) then max_quantity = target_item_count end 
            until true
        end

        quest_list_size = quest_list:get_Count()
        for i = (quest_list_size - 1), 0, -1 do
            if (max_quantity == 0) then quest_list:RemoveAt(i)
            else
                local quest_data       = quest_list:get_Item(i)
                local quest_reward_obj = quest_data:get_ExEnemyRewardItemInfo()
                local item_work_list   = export_rewards:call(reward_util, quest_reward_obj)
                local total_quantity   = 0
                for index = 0, item_work_list._size - 1 do
                    local item_work = item_work_list:get_Item(index)
                    if (target_item == tostring(item_work:get_ItemId())) then total_quantity = total_quantity + item_work.Num end
                end
                if (total_quantity < max_quantity) then quest_list:RemoveAt(i) end
            end
        end
    end,
    ["item_reward_target_reward_filter"] = function(quest_list, target_item)
        if not quest_list then return end

        local quest_list_size = quest_list:get_Count()
        if quest_list_size == 0 then return end 

        local item_quantity_list = {}
        for i = (quest_list_size - 1), 0, -1  do 
            local quest_data = quest_list:get_Item(i)
            if not quest_data then return end

            local reward_item_count = 0
            local quest_reward_obj  = quest_data:get_ExEnemyRewardItemInfo()
            local item_work_list    = export_rewards:call(reward_util, quest_reward_obj)
            for j = 0, item_work_list._size - 1 do 
                local item_work = item_work_list:get_Item(j)
                local item_id   = tostring(item_work:get_ItemId())
                if (item_id == target_item) then reward_item_count = reward_item_count + (item_work.Num or 0) end                
            end
            if (reward_item_count > 0) then table.insert(item_quantity_list, { num = reward_item_count, quest_data = quest_data }) end
        end
        table.sort(item_quantity_list, function(a, b) return (a.num > b.num) end)

        local active_count = #item_quantity_list
        for i = 0, (active_count - 1) do
            local index = i + 1
            quest_list:set_Item(i, item_quantity_list[index].quest_data)
        end

        for i = quest_list_size - 1, active_count, -1  do 
            local last_index = quest_list:get_Count() - 1
            if (last_index >= 0) then quest_list:RemoveAt(last_index) end
        end
    end,
}

local function draw_settings_checkbox(setting_name, filter)
    local changed, value = imgui.checkbox("##filter_sos_list_" .. setting_name, filter.enabled or false)
    if changed then filter.enabled = value end
    return value
end

local function draw_settings_text_input(setting_name, filter, min, max, default)
    local width = imgui.calc_text_size(tostring(max)).x + 10
    imgui.push_item_width(width)
    local changed, value = imgui.input_text("##filter_sos_list_" .. setting_name, filter.value, 4097)  -- Chars Decimal: 1, Auto Select All: 4096
    local value = tonumber(value) or default
    if changed and (value >= min) and (value <= max) then filter.value = value end
    imgui.pop_item_width()
    return value
end

local function draw_settings_comparison(setting_name, filter)
    imgui.push_item_width(UI_WIDTH.comparison_types)
    local          current_index    = COMPARISON_TYPE_LOOKUP[filter.comparison] or 1
    local changed, selected_index   = imgui.combo("##filter_sos_list_" .. setting_name, current_index, COMPARISON_TYPE_LIST)
    if changed then filter.comparison = COMPARISON_TYPE_LIST[selected_index] end
    imgui.pop_item_width()
end

local function draw_settings_menu(setting_name, filter, menus, selected_index, is_allow_multi_checked)
    if not imgui.begin_menu(setting_name .. "##menus" .. #menus, true) then return end
    local new_index = nil
    for i, name in ipairs(menus) do
        local is_checked = is_allow_multi_checked and (filter.list[name] == true) or (i == selected_index)
        if imgui.menu_item(get_localized_text(name), nil, is_checked, filter.enabled) then new_index = i end
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
local function draw_slider_range_int(id, current_min, current_max)
    if not id then id = "HR" end
    if is_window_open then
        local window_size  = imgui.get_window_size()
              slider_width = window_size.x - 24
    end
    local cursor_pos   = imgui.get_cursor_screen_pos()
          cursor_pos.x = cursor_pos.x + 10
    local display_text = string.format("%4d  <  Host " .. id .. "  <  %4d", current_min, current_max)
    if not UI_TEXT_SIZE[display_text] then UI_TEXT_SIZE[display_text] = imgui.calc_text_size(display_text) end
    local text_size     = UI_TEXT_SIZE[display_text]
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

local function draw_button(name, size)
    local style_button         = 21
    local style_button_hovered = 22
    local style_ButtonActive   = 23
    imgui.push_style_color(style_button,         0xFF2D5A27)
    imgui.push_style_color(style_button_hovered, 0xFF3D7A35)
    imgui.push_style_color(style_ButtonActive,   0xFF1B3817)
    imgui.push_style_var(imgui.ImGuiStyleVar.FrameRounding, 4.0)
    local is_clicked = imgui.button(name, size)
    imgui.pop_style_color(3)
    imgui.pop_style_var(1)
    return is_clicked
end

local function draw_mod_settings()
    imgui.spacing()
    draw_settings_checkbox("enabled", config)
    imgui.same_line()
    imgui.text("Mod")
    imgui.same_line()
    if config.enabled then imgui.text_colored("Enabled",  -16711936)
    else                   imgui.text_colored("Disabled", -16776961) end

    draw_settings_checkbox("keep_searching", config.keep_searching)
    imgui.begin_disabled(not config.keep_searching.enabled)
    imgui.same_line()
    imgui.text("Keep searching for SOS Quest")
    imgui.end_disabled()
    -- General SOS Filters ------------------------------------------------------------------------------------------------------------------------------------
    local filters = config.general_filters
    local filter
    imgui.separator()
    draw_settings_checkbox("sos_flare_quests_filter", filters)
    imgui.same_line()
    imgui.text(get_localized_text("SOS Flare Quests"))
    imgui.same_line()
    if not filters.enabled then imgui.text_colored("Disabled", -16776961)
    else                        imgui.text_colored("Enabled",  -16711936)
        -- Auto/Manual join approval --------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_join_approval
        imgui.indent(10); draw_settings_checkbox("filter_accept_setting", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.accept_modes)
        local accept_option_index = ACCEPT_MODE_LOOKUP[filter.value] or 1
        local changed, new_index  = imgui.combo("##filter_sos_list_accept_setting", accept_option_index, LOCALIZED_TEXT.ACCEPT_MODE)
        if changed then filter.value = ACCEPT_MODE_LIST[new_index] end
        imgui.pop_item_width()
        imgui.end_disabled()
        -- Quest Level ----------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_level
        imgui.indent(10); draw_settings_checkbox("filter_quest_level", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests " .. ((filter.comparison == "exactly") and "at" or "with"))
        imgui.same_line()
        draw_settings_comparison("quest_level_comparison", filter)
        imgui.same_line()
        draw_settings_text_input("quest_level_filter", filter, 1, 10, 8)
        imgui.same_line()
        imgui.text("quest level ")
        imgui.end_disabled() 
        -- Host hunter Rank -----------------------------------------------------------------------------------------------------------------------------------
        filter = filters.host_hr
        imgui.indent(10); draw_settings_checkbox("filter_host_hr", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with host HR limits")
        if filter.enabled then 
            imgui.indent(20); draw_settings_checkbox("filter_host_hr_threshold", filter.threshold); imgui.unindent(20)
            imgui.same_line(); imgui.text("Apply only if quest level is" .. ((filter.threshold.comparison == "exactly") and " at" or ""))
            imgui.same_line(); draw_settings_comparison("host_hr_threshold_comparison", filter.threshold)
            imgui.same_line(); draw_settings_text_input("host_hr_threshold_level_filter", filter.threshold, 1, 10, 8)
        end
        filter.min, filter.max = draw_slider_range_int("HR", filter.min, filter.max)
        imgui.end_disabled()
        -- Monster Name ---------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.monster_name
        imgui.indent(10); draw_settings_checkbox("monster_name", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests matching base name")
        imgui.indent(30)
        local boss_names_str  = nil
        local remaining_count = nil
        for _, name in ipairs(ENEMY_BOSS.NAME_LIST) do
            local id         = ENEMY_BOSS.NAME_MAP[name]
            local is_checked = filter.list[id] and (filter.list[id] == true)
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
            if draw_button("Reset##monster_names", { 50, 24 }) then filter.list = {} end
            imgui.same_line()
        end
        imgui.set_next_item_width(280)
        if imgui.begin_menu(boss_names_str .. "##menuName", true) then
            for _, name in ipairs(ENEMY_BOSS.NAME_LIST) do
                local id         = ENEMY_BOSS.NAME_MAP[name]
                local is_checked = filter.list[id] and (filter.list[id] == true)
                if imgui.menu_item(name, nil, is_checked, filter.enabled) then 
                    filter.list[id] = not is_checked 
                end
            end
            cursor_helper.draw_custom_cursor(config.cursor_scale)
            imgui.end_menu()
        end
        imgui.unindent(30)
        imgui.end_disabled()
        -- Misstion Type --------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.mission_type
        imgui.indent(10); draw_settings_checkbox("misstion_type", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only selected quest types")
        imgui.same_line()
        local mission_type_str = nil
              remaining_count  = nil
        for _, mission_type in ipairs(MISSION_TYPE_LIST) do 
            if filter.list[mission_type] then
                if not remaining_count then 
                    local next_str = (mission_type_str and mission_type_str .. "," or "") .. get_localized_text(mission_type)
                    if (imgui.calc_text_size(next_str).x > 130) then remaining_count  = 1
                    else                                             mission_type_str = next_str end
                else
                    remaining_count = remaining_count + 1
                end
            end
        end
        if     remaining_count                                  then mission_type_str = mission_type_str .. " and  +" .. tostring(remaining_count) .. " more"
        elseif not mission_type_str or (mission_type_str == "") then mission_type_str = "<No Mission Type Selected>"                                           end
        local new_index = draw_settings_menu(mission_type_str, filter, MISSION_TYPE_LIST, 0, true)
        if new_index then 
            local mission_type        = MISSION_TYPE_LIST[new_index]
            filter.list[mission_type] = not filter.list[mission_type]
        end
        imgui.end_disabled()
        -- Monster Species ------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.monster_species
        imgui.indent(10); draw_settings_checkbox("filter_monster_species", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line() 
        imgui.text("Show only quests with")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.enemy_species)
        local changed, new_index = imgui.combo("##filter_monster_species", filter.value, ENEMY_BOSS.SPECIES_MAP)
        if changed then filter.value = new_index end
        imgui.pop_item_width()
        imgui.same_line()
        imgui.text("targets ")
        imgui.end_disabled()
        -- Monster Threat -------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.monster_threat
        imgui.indent(10); draw_settings_checkbox("filter_monster_threat", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests " .. ((filter.comparison == "exactly") and "at" or "with"))
        imgui.same_line()
        draw_settings_comparison("monster_threat_comparison", filter)
        imgui.same_line()
        draw_settings_text_input("monster_threat_filter", filter, 1, 5, 3)
        imgui.same_line()
        imgui.text("threat level ")
        imgui.end_disabled()
        -- Monster Count --------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.monster_count
        imgui.indent(10); draw_settings_checkbox("monster_count", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("monster_count_comparison", filter)
        imgui.same_line()
        local value = draw_settings_text_input("monster_count_filter", filter, 1, 4, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "monster " or "monsters ")
        imgui.end_disabled()
        -- Current Player Count -------------------------------------------------------------------------------------------------------------------------------
        filter = filters.current_players
        imgui.indent(10); draw_settings_checkbox("filter_current_players", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("current_players_comparison", filter)
        imgui.same_line()
        local value = draw_settings_text_input("current_players_filter", filter, 1, 3, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "current player " or "current players ")
        imgui.end_disabled() 
        -- Max Player Count -----------------------------------------------------------------------------------------------------------------------------------
        filter = filters.max_players
        imgui.indent(10); draw_settings_checkbox("filter_max_players", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line() 
        imgui.text("Show only quests with")
        imgui.same_line()
        draw_settings_comparison("max_players_comparison", filter)
        imgui.same_line()
        draw_settings_text_input("max_players_filter", filter, 2, 4, 2)
        imgui.same_line()
        imgui.text("max players ")
        imgui.end_disabled()
        -- Limit Weapons---------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.limit_weapon
        imgui.indent(10); draw_settings_checkbox("limit_weapon", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests without selected weapons equipped")
        if filter.enabled then
            imgui.indent(20); draw_settings_checkbox("limit_weapon_reserve", filter.reserve); imgui.unindent(20)
            imgui.same_line()
            imgui.text("Apply filter to secondary weapons as well")
        end
        imgui.indent(30)
        local equipped_weapons_str = nil
              remaining_count      = nil
        for _, weapon in ipairs(WEAPON_LIST) do
            if filter.list[weapon] then
                if not remaining_count then
                    local next_str = (equipped_weapons_str and equipped_weapons_str .. "," or "") .. get_localized_text(weapon)
                    if (imgui.calc_text_size(next_str).x > 200) then remaining_count      = 1
                    else                                             equipped_weapons_str = next_str end
                else
                    remaining_count = remaining_count + 1
                end
            end
        end
        if     remaining_count                                          then equipped_weapons_str = equipped_weapons_str .. " and  +" .. tostring(remaining_count) .. " more"
        elseif not equipped_weapons_str or (equipped_weapons_str == "") then equipped_weapons_str = "<No Weapon Selected>"                                                    end
        if remaining_count then
            if draw_button("Reset##limit_weapons", { 50, 24 }) then filter.list = {} end
            imgui.same_line()
        end
        local new_index = draw_settings_menu(equipped_weapons_str, filter, WEAPON_LIST, 0, true)
        if new_index then 
            local weapon        = WEAPON_LIST[new_index]
            filter.list[weapon] = not filter.list[weapon]
        end
        imgui.unindent(30)
        imgui.end_disabled()
        -- Started Time ---------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_started_time
        imgui.indent(10); draw_settings_checkbox("filter_started_time", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests started within the last")
        imgui.same_line()
        local value = draw_settings_text_input("started_time_filter", filter, 1, 60, 1)
        imgui.same_line()
        imgui.text((tonumber(value) == 1) and "minute " or "minutes ")
        imgui.end_disabled()
        -- Multiplay Setting ----------------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_multiplay_setting
        imgui.indent(10); draw_settings_checkbox("filter_multiplay_setting", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests that allow")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.multiplay_types)
        local multiplay_index = MULTIPLAY_TYPE_LOOKUP[filter.value] or 1
        local changed, new_index = imgui.combo("##filter_sos_list_multiplay_setting_filter", multiplay_index, LOCALIZED_TEXT.MULTIPLAY_TYPES)
        imgui.pop_item_width()
        if changed then filter.value = MULTIPLAY_TYPE_LIST[new_index] end
        imgui.end_disabled()
        -- Quest Field Setting --------------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_fields
        imgui.indent(10); draw_settings_checkbox("filter_field", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests in")
        imgui.same_line()
        local field_str       = nil
              remaining_count = nil
        for _, field in ipairs(FIELD_LIST) do
            if filter.list[field] then
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
        local new_index = draw_settings_menu(field_str, filter, FIELD_LIST, 0, true)
        if new_index then 
            local field      = FIELD_LIST[new_index]
            filter.list[field] = not filter.list[field]
        end
        imgui.end_disabled()
        -- Environment Setting --------------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_environment
        imgui.indent(10); draw_settings_checkbox("filter_environment", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests in")
        imgui.same_line()
        local environments_str = nil
              remaining_count  = nil
        for _, environment in ipairs(ENVIRONMENT_LIST) do
            if filter.list[environment] then
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
        local new_index = draw_settings_menu(environments_str, filter, ENVIRONMENT_LIST, 0, true)
        if new_index then 
            local env      = ENVIRONMENT_LIST[new_index]
            filter.list[env] = not filter.list[env]
        end
        imgui.end_disabled()
        -- Wishlist Monster -----------------------------------------------------------------------------------------------------------------------------------
        filter = filters.wishlist
        imgui.indent(10); draw_settings_checkbox("filter_wishlist", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with wishlisted monster drops ")
        imgui.end_disabled()
        -- Gathering Boost Quest ------------------------------------------------------------------------------------------------------------------------------
        filter = filters.gathering_boost
        imgui.indent(10); draw_settings_checkbox("gathering_boost", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with \"" .. get_localized_text("gathering boost") .. "\"")
        imgui.end_disabled()
        -- Blocked Users --------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.blocked_users
        imgui.indent(10); draw_settings_checkbox("filter_blocked_users", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Hide Quests with Blocked Users")
        imgui.end_disabled()
    end
    -- Item Filters -------------------------------------------------------------------------------------------------------------------------------------------
    filter = config.item_filters
    draw_settings_checkbox("item_filters_enabled", filter)
    imgui.same_line()
    imgui.text(get_localized_text("Bonus Rewards"))
    imgui.same_line()

    if not filter.enabled then imgui.text_colored("Disabled", -16776961)
    else                       imgui.text_colored("Enabled",  -16711936)
        imgui.indent(10)
        imgui.text("Filter Mode:")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.filter_modes)
        local filter_style_index = FILTER_MODE_LOOKUP[filter.mode] or 1
        local changed, new_index = imgui.combo("##item_filter_mode", filter_style_index, FILTER_MODE_LIST)
        if changed then filter.mode = FILTER_MODE_LIST[new_index] end
        imgui.pop_item_width()
        if (filter_style_index == 1) then  -- Custom
            local filtering = ITEM_FILTERS.CUSTOM_MODE
                  filter    = filter.custom
            imgui.text("Custom Reward Filters:")
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.custom_mode_operators)
            if not filter.operator then filter.operator = "AND" end
            local custom_list_style_index = filtering.operator_lookup[filter.operator] or 1
            local changed, new_index = imgui.combo("##item_filter_operator", custom_list_style_index, filtering.operators)
            if changed then filter.operator = filtering.operators[new_index] end
            imgui.pop_item_width()
            imgui.text("Show SOS quests where")
            for item_id, item_num in pairs(filter.target_list) do
                if item_num then
                    if draw_button("-##item_filter_Remove_" .. item_id, { 24, 24 }) then
                        filter.target_list[item_id] = false
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
                    if changed and (value >= 1) and (value <= 99) then filter.target_list[item_id] = value end
                    imgui.pop_item_width()
                    imgui.same_line()
                    imgui.text((value == 1) and "time" or "times")
                    imgui.indent(30)
                    imgui.text(filter.operator)
                    imgui.unindent(30)
                end
            end
            imgui.same_line()
            imgui.text("..?")
            if (#filtering.list > 0) then
                if draw_button("+##item_filter_Add", { 24, 24 }) and (filtering.selected_index > 0) then
                    local selected_item_id = filtering.lookup[filtering.selected_index]
                    filter.target_list[selected_item_id] = 1
                    filtering.update()
                end
            else
                imgui.invisible_button("#item_filter_Invisible_button", { 24, 24 })
            end
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.localized_items)
            local item_name    = filtering.list[filtering.selected_index]
            local selected_str = item_name and get_localized_text(item_name) or "<No more items can be selected>"
            local new_index    = draw_settings_menu(selected_str, filter, filtering.list, item_name and filtering.selected_index or 0, false)
            if new_index then filtering.selected_index = new_index end
            imgui.pop_item_width()
        elseif (filter_style_index == 2) then  -- Max Quantity
            local filtering = ITEM_FILTERS.REQUIRED_REWARDS
                  filter    = filter.max_quantity
            imgui.text("Highest Quantity of ")
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.localized_items)
            local selected_index = filtering.lookup[filter.target_item] or 1
            local selected_str   = get_localized_text(filtering.list[selected_index]) or "<No Item Selected> "
            local new_index      = draw_settings_menu(selected_str, filtering, filtering.list, selected_index, false)
            if new_index then filter.target_item = ITEM_NAME_MAP[filtering.list[new_index]] end
            imgui.pop_item_width()
        else  -- Target Reward Filter
            local filtering = ITEM_FILTERS.REQUIRED_REWARDS
                  filter    = filter.target_reward_filter
            imgui.text("Sort by ")
            imgui.same_line()
            imgui.push_item_width(UI_WIDTH.localized_items)
            local selected_index = filtering.lookup[filter.target_item] or 1
            local selected_str   = get_localized_text(filtering.list[selected_index]) or " <No Item Selected> "
            local new_index      = draw_settings_menu(selected_str .. "  (High to Low)", filtering, filtering.list, selected_index, false)
            if new_index then filter.target_item = ITEM_NAME_MAP[filtering.list[new_index]] end
            imgui.pop_item_width()
        end
        imgui.unindent(10)
    end
    -- Lobby Member Quest Filters -----------------------------------------------------------------------------------------------------------------------------
    filters = config.lobby_member_quest_filters
    imgui.separator()
    draw_settings_checkbox("general_lobby_member_filters", filters)
    imgui.same_line()
    imgui.text(get_localized_text("Lobby Member Quests"))
    imgui.same_line()
    if not filters.enabled then imgui.text_colored("Disabled", -16776961)
    else                        imgui.text_colored("Enabled",  -16711936)
        -- Auto/Manual join approval --------------------------------------------------------------------------------------------------------------------------
        filter = filters.quest_join_approval
        imgui.indent(10); draw_settings_checkbox("filter_lobby_member_quest_accept_setting", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with ")
        imgui.same_line()
        imgui.push_item_width(UI_WIDTH.accept_modes)
        local accept_option_index = ACCEPT_MODE_LOOKUP[filter.value] or 1
        local changed, new_index  = imgui.combo("##filter_lobby_member_quest_list_accept_setting", accept_option_index, LOCALIZED_TEXT.ACCEPT_MODE)
        if changed then filter.value = ACCEPT_MODE_LIST[new_index] end
        imgui.pop_item_width()
        imgui.end_disabled()
        -- without a password ---------------------------------------------------------------------------------------------------------------------------------
        filter = filters.without_password
        imgui.indent(10); draw_settings_checkbox("filter_lobby_member_quest_without_password", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests without a password")
        imgui.end_disabled()
        -- available slots ----------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.joinable_quest
        imgui.indent(10); draw_settings_checkbox("filter_lobby_member_quest_joinable_quest", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Show only quests with available slots")
        imgui.end_disabled()
        --- blocked users ----------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.blocked_users
        imgui.indent(10); draw_settings_checkbox("filter_lobby_member_quest_blocked_users", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Hide Quests with Blocked Users")
        imgui.end_disabled()
        --- sos flare active -------------------------------------------------------------------------------------------------------------------------------------
        filter = filters.sos_flare_active
        imgui.indent(10); draw_settings_checkbox("filter_lobby_member_quest_sos_flare_active", filter); imgui.unindent(10)
        imgui.begin_disabled(not filter.enabled)
        imgui.same_line()
        imgui.text("Hide Quests with SOS Flares Active")
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

local keep_searching = {
    enabled                      = false,
    is_open_dialog_failed_search = false,
    context_ptr                  = nil,
}
function keep_searching.start()
    if not config.enabled or not (config.general_filters.enabled or config.item_filters.enabled) then return end
    if keep_searching.enabled then is_window_open = true
    else
        keep_searching.enabled                      = config.keep_searching.enabled
        keep_searching.is_open_dialog_failed_search = false
        is_window_open                              = false
    end
end
function keep_searching.stop()
    if keep_searching.context_ptr then
        keep_searching.context_ptr:set_field("IsSearchAgain", false)
        keep_searching.context_ptr:set_field("IsCancel",      false)
        keep_searching.context_ptr = nil
        is_window_open             = false
    end
    keep_searching.enabled = false
end

function keep_searching.search_again(context)
    if not config.enabled or not keep_searching.enabled then return                               end
    if context                                          then keep_searching.context_ptr = context end
    if not keep_searching.context_ptr                   then return                               end

    is_window_open = true
    keep_searching.context_ptr:set_field("IsSearchAgain", true)
    keep_searching.context_ptr:set_field("IsCancel",      true)
end

local function open_mod_settings_window()
    is_window_open = true
    save_config()
end

local function close_mod_settings_window()
    is_window_open = false
    save_config()
end

local window_width
local function center_text(text, font_size, color)
    if font_size then imgui.push_font_size(font_size) end
    
    if not UI_TEXT_SIZE[text] then UI_TEXT_SIZE[text] = imgui.calc_text_size(text) end
    local text_width  = UI_TEXT_SIZE[text].x
    local current_pos = imgui.get_cursor_pos()
    local target_x    = (window_width - text_width) * 0.5
    imgui.set_cursor_pos({ target_x, current_pos.y })
    
    if color then imgui.text_colored(text, color)
    else          imgui.text(text)                end
    
    if font_size then imgui.pop_font_size() end
end

local was_cancel_key_down = false
local function draw_mod_keep_searching()
    if keep_searching.context_ptr then
        local is_cancel_key_down = imgui.is_key_down(imgui.ImGuiKey.Key_Escape) or imgui.is_key_down(imgui.ImGuiKey.Key_MouseRight)
        if is_cancel_key_down and not was_cancel_key_down then keep_searching.stop() end
        was_cancel_key_down = is_cancel_key_down
    end

    window_width = imgui.get_window_size().x
    imgui.spacing()
    center_text("Auto Searching......", 36, 0xFF00FFFF)
    imgui.separator()
    imgui.spacing()
    center_text("Minor flickering is inevitable due to the system's nature,", nil, nil)
    center_text("as the mod continuously cycles through the in-game UI steps.", nil, nil)
    imgui.spacing()
    center_text("To Stop: Press Keyboard [ESC] or Mouse [Right] button.", 18, 0xFF00FF00)    
    imgui.spacing(); imgui.spacing();

    local button_width = 410
    local button_size  = { button_width, 50 }    
    local current_pos  = imgui.get_cursor_pos()
    local button_x     = (window_width - button_width) * 0.5
    imgui.set_cursor_pos({ button_x, current_pos.y })
    imgui.push_font_size(24)
    if draw_button("[ Stop Auto-Searching ] ", button_size) then keep_searching.stop() end
    imgui.pop_font_size()
    imgui.spacing()
    cursor_helper.draw_custom_cursor(config.cursor_scale)
end

re.on_frame(function() 
    if not is_window_open or not imgui.begin_window(MOD_TITLE, nil, 120) then return end  -- 8:NoScrollBar, 16:NoScrollWithMouse, 32:NoCollapse, 64:AlwaysAutoResize
    if not keep_searching.enabled then draw_mod_settings()
    else                               draw_mod_keep_searching() end
    imgui.end_window() 
end)

sdk.hook(sdk.find_type_definition("app.GUI050000QuestListParts"):get_method("sortQuestDataList(System.Boolean)"), function(args)
    if not config.enabled then return end
    local quest_list_parts = sdk.to_managed_object(args[2])
    local category         = quest_list_parts:get_field("<ViewCategory>k__BackingField")
    if not ((category == SERCH_RESCUE_SIGNAL) or (category == RECRUITMENT_LOBBY)) then return end
    local quest_list      = quest_list_parts:get_field("<ViewQuestDataList>k__BackingField")
    local pre_hook_result = sdk.PreHookResult.CALL_ORIGINAL
    repeat
        local quest_list_size = quest_list:get_Count()
        if (quest_list_size <= 0) then break end

        local filter, reward_filter, is_custom_mode = nil, nil, nil
        if (category == RECRUITMENT_LOBBY) then filter = config.lobby_member_quest_filters 
        else
            filter        = config.general_filters
            reward_filter = config.item_filters
            if reward_filter.enabled then is_custom_mode = (reward_filter.mode == "Custom") end
        end

        for i = quest_list_size - 1, 0, -1 do
            local quest_data = quest_list:get_Item(i)
            if quest_data then
                local should_remove = false
                for _, filter_name in ipairs(filter_order) do
                    local filter_config = filter[filter_name] or (((filter_name == "item_reward_custom") and is_custom_mode) and reward_filter)
                    if filter_config and filter_config.enabled then
                        local filter_method = filter_methods[filter_name]
                        if filter_method and filter_method(quest_data, filter_config) then should_remove = true; break end
                    end
                end
                if should_remove then quest_list:RemoveAt(i) end
            end
        end

        if reward_filter and reward_filter.enabled and not is_custom_mode then
            if (reward_filter.mode == "Max Quantity") then filter_methods["item_reward_max_quantity"](quest_list, reward_filter.max_quantity.target_item)
            else                                           filter_methods["item_reward_target_reward_filter"](quest_list, reward_filter.target_reward_filter.target_item)
                                                           pre_hook_result = sdk.PreHookResult.SKIP_ORIGINAL
            end
        end
    until true
    if keep_searching.enabled then
        if (quest_list:get_Count() == 0) and (quest_list_parts:get_ViewCategory() == SERCH_RESCUE_SIGNAL) then 
            local gui050000 = quest_list_parts:get_QuestCounterUI()
            local context   = gui050000:get_ViewFlowContext()
            keep_searching.search_again(context)
        else
            keep_searching.stop()
        end
    end
return pre_hook_result end)

sdk.hook(sdk.find_type_definition("app.GUI050000"):get_method("setQuestListInCategory(app.GUI050000.CATEGORY)"), function(args)
    local category = sdk.to_int64(args[3])
    if (category == SERCH_RESCUE_SIGNAL) or (category == RECRUITMENT_LOBBY) then  open_mod_settings_window()
    else                                                                         close_mod_settings_window() end
return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.GUI050000"):get_method("closeQuestDetailWindow()"),                   function(args) close_mod_settings_window() return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.cGUI050000ViewFlow.Flow.RescueSetting"):get_method("onEnter()"),      function(args) open_mod_settings_window()  return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.cGUI050000ViewFlow.Flow.RescueSetting"):get_method("nextFlow()"),     function(args) keep_searching.start()      return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.cGUI050000ViewFlow.Flow.RescueSetting"):get_method("cancelFlow()"),   function(args) keep_searching.stop()       return sdk.PreHookResult.CALL_ORIGINAL end)
sdk.hook(sdk.find_type_definition("app.GUI050000"):get_method("openDialog_faildSearchQuest(System.Action)"), function(args)
    if not config.enabled or not keep_searching.enabled then return sdk.PreHookResult.CALL_ORIGINAL end
    local gui     = sdk.to_managed_object(args[2])
    local context = gui:get_ViewFlowContext()
    if (context.QuestCategory == SERCH_RESCUE_SIGNAL) then 
        keep_searching.is_open_dialog_failed_search = true
        keep_searching.search_again(context)
    end
return sdk.PreHookResult.CALL_ORIGINAL end)

sdk.hook(sdk.find_type_definition("app.cGUISystemModuleNotifyWindowApp"):get_method("openGUI()"), function(args)
    if not config.enabled or not keep_searching.enabled or not keep_searching.is_open_dialog_failed_search then return sdk.PreHookResult.CALL_ORIGINAL end
    keep_searching.is_open_dialog_failed_search = false
    local notifyWindow  = sdk.to_managed_object(args[2])
    local currentWindow = notifyWindow:get__CurInfoApp()
    currentWindow:executeWindowEndFunc()
return sdk.PreHookResult.SKIP_ORIGINAL end)

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
