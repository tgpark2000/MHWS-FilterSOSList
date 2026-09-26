local UI_TEXT = {
    language_code       = "en",       -- example) English: en, Korean: ko, Japanese: ja 
    language_name       = "English",  -- String to be displayed in the combo menu.

    WINDOW_OPEN_MSG_1   = "The dedicated menu is now active.",
    WINDOW_OPEN_MSG_2   = "Please use the in-game window.",
    ENABLED             = "Enabled",
    DISABLED            = "Disabled",
    KEEP_SEARCHING      = "Keep searching for SOS Quest",
    QUEST_JOIN_APPROVAL = {
        DISABLED = "Show only quests with selected join approval",
        ENABLED  = "Quest Join Approval:",
    },
    QUEST_LEVEL = {
        DISABLED           = "Show only quests within quest levels",
        SLIDER_CENTER_TEXT = "Quest Level",
    },
    HOST_HR = {
        DISABLED                     = "Show only quests with host HR limits",
        THRESHOLD_DISABLED           = "Apply only if within quest levels",
        THRESHOLD_ENABLED            = "Apply only:",
        SLIDER_CENTER_TEXT           = "Host HR",
        SLIDER_CENTER_TEXT_THRESHOLD = "Quest Level",
    },
    MONSTER_NAME = {
        DISABLED = "Show only quests matching base name ",
        NO_SELECTED = "<No Monster Name Selected>",
        AND         = "and +",
        MORE        = " more",
        RESET       = "Reset",
    },
    MISSION_TYPE = {
        DISABLED    = "Show only selected quest types",
        NO_SELECTED = "<No Mission Type Selected>",
        AND         = "and +",
        MORE        = " more",
    },
    MONSTER_SPECIES = {
        DISABLED    = "Show only quests with selected monster species",
        NO_SELECTED = "<No Monster Species Selected>",
        AND         = "and +",
        MORE        = " more",
        RESET       = "Reset"
    },
    MONSTER_THREAT = {
        DISABLED           = "Show only quests within monster threat levels",
        SLIDER_CENTER_TEXT = "Monster Threat Level",
    },
    MONSTER_COUNT = {
        DISABLED           = "Show only quests within a monster count",
        SLIDER_CENTER_TEXT = "Monster Count",
    },
    CURRENT_PLAYERS = {
        DISABLED           = "Show only quests within a player count",
        SLIDER_CENTER_TEXT = "Current players",
    },
    MAX_PLAYERS = {
        DISABLED           = "Show only quests within player limits",
        SLIDER_CENTER_TEXT = "Max players",
    },
    LIMIT_WEAPON = {
        DISABLED         = "Show only quests without selected weapons equipped",
        NO_SELECTED      = "<No Weapon Selected>",
        AND              = "and +",
        MORE             = " more",
        RESET            = "Reset",
        APPLY_SECONDDARY = "Apply filter to secondary weapons as well",
    },
    STARTED_TIME = {
        DISABLED    = "Show only quests started within a specific time",
        SLIDER_CENTER_TEXT = "Elapsed Time",
    },
    MULTIPLAY_SETTINGS = {
        DISABLED = "Show only quests that allow selected multiplay settings",
        ENABLED  = "Multiplay Settings:",
        AND      = "and +",
        MORE     = " more",
    },
    QUEST_FIELDS = {
        DISABLED    = "Show only quests in selected fields",
        NO_SELECTED = "<No Fields Selected>",
        AND         = "and +",
        MORE        = " more",
    },
    QUEST_ENV = {
        DISABLED    = "Show only quests in selected environments",
        NO_SELECTED = "<No Environments Selected>",
        AND         = "and +",
        MORE        = " more",
    },
    WHITELIST_DROP = {
        TEXT = "Show only quests with wishlisted monster drops",
    },
    BLOCKED_USERS = {
        TEXT = "Hide Quests with Blocked Users",
    },
    REWARD_ITEMS = {
        MODE                 = "Filter Mode:",
        CUSTOM               = "Custom",
        MAX_QUANTITY         = "Max Quantity",
        TARGET_REWARD_FILTER = "Target Reward Filter",
        CUSTOM_MODE_FILTER   = "Custom Reward Filters:",
        SHOW_SOS_QUEST_WHERE = "Show SOS quests where",
        APPEARS_AT_LEAST     = "appears at least",
        TIME                 = "time",
        TIMES                = "times",
        NO_MORE_ITEMS        = "<No more items can be selected>",
        NO_ITEM_SELECTED     = "<No Item Selected>",
        HIGHEST_QUANTITY     = "Highest Quantity of ",
        SORT_BY              = "Sort by ",
        DESCENDING           = "  (High to Low)",
    },
    WITHOUT_PASSWORD = {
        TEXT = "Show only quests without a password",
    },
    AVALIABLE_SLOTS = {
        TEXT = "Show only quests with available slots",
    },
    SOS_FLARE_ACTIVE = {
        TEXT = "Hide Quests with SOS Flares Active",
    },
    AUTO_SEARCHING = {
        TITLE         = "Auto Searching......",
        CAUSTION      = "Minor flickering is inevitable due to the system's nature",
        CAUSTION_2    = "as the mod continuously cycles through the in-game UI steps.",
        HOW_TO_STOP   = "To Stop: Press Keyboard [ESC] or Mouse [Right] button.",
        HOW_TO_STOP_2 = "Or click the green [Stop Auto-Searching] button below.",
        HOW_TO_STOP_3 = "",
        STOP_BUTTON   = "[ Stop Auto-Searching ] ",
    },
}

return UI_TEXT