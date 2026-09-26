local this = {
    language_code     = "ko",      -- example) English: en, Korean: ko, Japanese: ja 
    language_name     = "한국어",  -- String to be displayed in the combo menu.

    WINDOW_OPEN_MSG_1 = "전용 메뉴창이 활성화 되어 있습니다.",
    WINDOW_OPEN_MSG_2 = "화면에 새로 띄워진 메뉴창을 이용해주세요.",
    ENABLED           = "작동중",
    DISABLED          = "작동 중지",
    KEEP_SEARCHING    = "구조신호 퀘스트에서 자동으로 재검색",
    QUEST_JOIN_APPROVAL = {
        DISABLED = "설정한 참가 승인 모드의 퀘스트만 보여줍니다",
        ENABLED  = "참가 승인 모드:",
    },
    QUEST_LEVEL = {
        DISABLED           = "설정한 퀘스트 난이도만 보여줍니다",
        SLIDER_CENTER_TEXT = "퀘스트 난이도",
    },
    HOST_HR = {
        DISABLED                     = "설정한 호스트(방장)의 HR에 해당하는 퀘스트만 보여줍니다",
        THRESHOLD_DISABLED           = "해당하는 퀘스트 난이도에만 적용합니다",
        THRESHOLD_ENABLED            = "적용할 퀘스트 난이도:",
        SLIDER_CENTER_TEXT           = "호스트(방장)의 HR",
        SLIDER_CENTER_TEXT_THRESHOLD = "퀘스트 난이도",
    },
    MONSTER_NAME = {
        DISABLED    = "선택된 몬스터 이름과 일치하는 퀘스트만 보여줍니다",
        NO_SELECTED = "<선택된 몬스터 이름이 없습니다>",
        AND         = " 외 +",
        MORE        = "마리",
        RESET       = "리셋",
    },
    MISSION_TYPE = {
        DISABLED    = "선택된 퀘스트 종류만 보여줍니다",
        NO_SELECTED = "<선택된 퀘스트 종류이 없습니다>",
        AND         = " 외 +",
        MORE        = "개",
        RESET       = "리셋",
    },
    MONSTER_SPECIES = {
        DISABLED    = "선택된 몬스터 종에 일치하는 퀘스트만 보여줍니다",
        NO_SELECTED = "<선택된 몬스터 종이 없습니다>",
        AND         = " 외 +",
        MORE        = "종",
        RESET       = "리셋",
    },
    MONSTER_THREAT = {
        DISABLED           = "몬스터 위험도에 일치하는 퀘스트만 보여줍니다",
        SLIDER_CENTER_TEXT = "몬스터 위험도",
    },
    MONSTER_COUNT = {
        DISABLED           = "설정한 몬스터 수에 해당하는 퀘스트만 보여줍니다",
        SLIDER_CENTER_TEXT = "몬스터 수",
    },
    CURRENT_PLAYERS = {
        DISABLED           = "설정한 현재 인원에 해당하는 퀘스트만 보여줍니다",
        SLIDER_CENTER_TEXT = "현재 인원",
    },
    MAX_PLAYERS = {
        DISABLED           = "설정한 최대 인원에 해댕하는 퀘스트만 보여줍니다",
        SLIDER_CENTER_TEXT = "최대 인원",
    },
    LIMIT_WEAPON = {
        DISABLED         = "멤버들이 설정된 무기를 장착하지 않은 퀘스트만 보여줍니다 ",
        NO_SELECTED      = "<선택된 무기가 없습니다>",
        AND              = " 외 +",
        MORE             = "종",
        RESET            = "리셋",
        APPLY_SECONDDARY = "장착된 서브 무기도 적용합니다",
    },
    STARTED_TIME = {
        DISABLED           = "설정한 경과 시간에 해당하는 퀘스트만 보여줍니다",
        SLIDER_CENTER_TEXT = "경과 시간",
    },
    MULTIPLAY_SETTINGS = {
        DISABLED = "멀티플레이 설정에 해당하는 퀘스트만 보여줍니다",
        ENABLED  = "멀티플레이 설정:",
    },
    QUEST_FIELDS = {
        DISABLED    = "선택된 필드에 해당하는 퀘스트만 보여줍니다",
        NO_SELECTED = "<선택된 필드가 없습니다>",
        AND         = " 외 +",
        MORE        = "곳",
    },
    QUEST_ENV = {
        DISABLED    = "선택된 환경에 해당하는 퀘스트만 보여줍니다",
        NO_SELECTED = "<선택된 환경이 없습니다>",
        AND         = " 외 +",
        MORE        = "",
    },
    WHITELIST_DROP = {
        TEXT = "찜 목록의 아이템을 얻을 수 있는 퀘스트만 보여줍니다",
    },
    BLOCKED_USERS = {
        TEXT = "차단한 유저가 없는 퀘스트만 보여줍니다",
    },
    REWARD_ITEMS = {
        MODE                 = "필터링 모드:",
        CUSTOM               = "조건 설정",
        MAX_QUANTITY         = "최대 수량만",
        TARGET_REWARD_FILTER = "대상 아이템 수량 정렬",
        CUSTOM_MODE_FILTER   = "보상 아이템 커스텀",
        SHOW_SOS_QUEST_WHERE = "다음 조건을 만족하는 퀘스트만 보여줍니다",
        APPEARS_AT_LEAST     = "  적어도 ",
        TIME                 = "개",
        TIMES                = "개",
        NO_MORE_ITEMS        = "<더이상 선택할 수 있는 아이템이 없습니다>",
        NO_ITEM_SELECTED     = "<선택된 아이템이 없습니다>",
        HIGHEST_QUANTITY     = "가장 많은 아이템 대상: ",
        SORT_BY              = "정렬 대상: ",
        DESCENDING           = "  (내림차순)",
    },
    WITHOUT_PASSWORD = {
        TEXT = "비밀번호가 없는 퀘스트만 보여줍니다",
    },
    AVALIABLE_SLOTS = {
        TEXT = "참가할 수 있는 퀘스트만 보여줍니다",
    },
    SOS_FLARE_ACTIVE = {
        TEXT = "구조신호를 켜지 않은 퀘스트만 보여줍니다",
    },
    AUTO_SEARCHING = {
        TITLE         = "자동 재검색중......",
        CAUSTION      = "자동 재검색 기능은 게임 UI의 재검색 기능을 그대로 따라하기 때문에",
        CAUSTION_2    = "UI 전환으로 인한 깜박이는 현상이 발생할 수 밖에 없습니다.",
        HOW_TO_STOP   = "  멈추기 위해선 키보드의 [ESC], 마우스의 [오른쪽 버튼]을 누르거나  ",
        HOW_TO_STOP_2 = "아래 녹색 [Stop Auto-Searching] 버튼을 클릭하세요.",
        HOW_TO_STOP_3 = "",
        STOP_BUTTON   = "[ Stop Auto-Searching ] ",
    },
}

return this