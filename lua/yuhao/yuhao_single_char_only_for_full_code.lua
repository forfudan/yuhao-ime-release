--[[
Name: yuhao_single_char_only_for_full_code.lua
名稱: 全碼詞語過濾器
Version: 20260126
Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
Purpose: 屏蔽全碼詞語,但保留簡碼詞
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
-------------------------------------

介紹:
對於單字黨而言,有時候也希望能够通過輸入簡碼詞語提高打字速度.
這個過濾器會過濾掉全碼詞語,只保留單字和簡碼詞.

使用方法:
(1) 需要將此 lua 文件放在 lua 文件夾下.
(2) 需要在 rime.lua 中添加以下代码激活本腳本:
yuhao_single_char_only_for_full_code  = require("yuhao_single_char_only_for_full_code")
(3) 需要在 switches 添加狀態:
- name: yuhao_single_char_only_for_full_code
reset: 1
states: [字词同出, 全码出单]
(4) 需要在 engine/filters 添加:
- lua_filter@yuhao_single_char_only_for_full_code

版本:
20221108: 初版.
20250602: 將四碼改爲四碼及以上.
20250819: 重構代碼.用户每次輸入編碼時,都會搜索碼表,確認是否是簡碼詞.
20251220: 使用 core.is_single_char 函數處理單字判斷,正確支持變體選擇器.
20260109: 修改邏輯:碼長爲1或2時,直接認定爲簡碼,無需檢查是否存在更長的碼.
20260126: 修改邏輯:碼長小於4時,直接認定爲簡碼,無需檢查是否存在更長的碼.
20260210: 允許預測候選項顯示簡碼詞.
20260212: 修改預測候選項的簡碼判斷邏輯:如果輸入碼長+預測碼長小於等於3,
          則認定爲簡碼.
20260303: 增加常用詞語白名單功能.如果候選詞在白名單中,則永遠顯示.
20260608: 四字以上的詞語永遠直接顯示.
---------------------------
]]

local core = require("yuhao.yuhao_core")

local function init(env)
    local config = env.engine.schema.config
    local code_rvdb = config:get_string("schema_name/code")
    env.code_rvdb = ReverseDb("build/" .. code_rvdb .. ".reverse.bin")
    env.mem = Memory(env.engine, Schema(code_rvdb))

    -- 讀取 schema_name/words，加載對應的常用詞語白名單
    env.words_whitelist = nil
    local words_key = config:get_string("schema_name/words")
    if words_key and words_key ~= "" then
        local ok, yuhao_words = pcall(require, "yuhao.yuhao_words")
        if ok and yuhao_words[words_key] then
            env.words_whitelist = {}
            for word in yuhao_words[words_key]:gmatch("%S+") do
                env.words_whitelist[word] = true
            end
        end
    end
end

-- 檢查精確匹配候選項是否是簡碼
-- 1. 如果該候選項的長度（輸入碼長）小於等於閾值，則認爲它是簡碼。
-- 2. 如果該候選項存在一個更長的編碼，則認爲它是簡碼
local function is_short_code(cand, env, threshold)
    local length_of_input = string.len(env.engine.context.input)
    local codes_of_candidates = env.code_rvdb:lookup(cand.text)
    local is_short = false
    -- 如果輸入碼長小於等於閾值，直接認定爲簡碼
    if length_of_input <= threshold then
        return true
    end
    for code in codes_of_candidates:gmatch("%S+") do
        -- 如果該候選項存在一個更長的碼，則認爲它是簡碼
        if string.len(code) > length_of_input then
            is_short = true
            break
        end
    end
    return is_short
end

-- 檢查預測候選項是否是簡碼
-- 如果該候選項的長度（輸入碼長 + 預測碼長）小於等於閾值，則認爲它是簡碼。
local function is_auto_completion_short_code(cand, env, threshold)
    local length_of_input = string.len(env.engine.context.input)
    local length_of_auto_completion = string.len(cand.comment)
    -- 如果輸入碼長 + 預測碼長小於等於閾值，直接認定爲簡碼
    -- 朱按：這個地方減1是因爲提示區域似乎會顯示一個空格，佔用一個字符位置，
    -- 所以實際上預測碼長要減去1才能得到真正的預測碼長。
    if length_of_input + length_of_auto_completion - 1 <= threshold then
        return true
    else
        return false
    end
end

local function filter(input, env)
    local option = env.engine.context:get_option("yuhao_single_char_only_for_full_code")
    if not option then
        for cand in input:iter() do
            yield(cand)
        end
    elseif env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
    else
        for cand in input:iter() do
            -- 白名單詞語永遠顯示
            if env.words_whitelist and env.words_whitelist[cand.text] then
                yield(cand)
            else
                local cand_genuine = cand:get_genuine()
                if cand_genuine.type == 'completion' then
                    -- 預測候選項允許簡詞
                    -- 編碼長小於等於3的候選項直接顯示
                    if core.is_single_char(cand.text) or utf8.len(cand.text) >= 4 or is_auto_completion_short_code(cand, env, 3) then
                        yield(cand)
                    end
                else
                    -- 精確匹配允許簡詞
                    -- 編碼長小於等於3的候選項直接認定爲簡碼
                    -- 單字和四字以上的詞語直接顯示
                    if core.is_single_char(cand.text) or utf8.len(cand.text) >= 4 or is_short_code(cand, env, 3) then
                        yield(cand)
                    end
                end
            end
        end
    end
end

return { init = init, func = filter }
