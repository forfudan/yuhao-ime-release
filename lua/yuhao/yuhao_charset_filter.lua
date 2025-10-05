--[[
Name: yuhao_charset_filter.lua
名称: 常用繁簡字符過濾腳本
Version: 20240512
Author: 朱宇浩 (forFudan) <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
Purpose: 從候選項中過濾出常用繁簡漢字
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0
    International
------------------------------------------------------------------------

介紹:
字符過濾 charaset_filter 在鼠鬚管中不再有效,因爲 librime-charcode 被
    單獨出来作爲插件.
所以我寫了這個 lua 腳本過濾:
    - 常用繁簡漢字 (通用規範漢字 + 國字常用字 + 部分古籍通規字).
    - 通用規範漢字表約 8000 字.
    - 調和大陸繁體標準約 8000 字.
        古籍通規繁體標準 及 調和大陸繁體標準 詳見
        <https://github.com/forFudan/GujiCC>
非 CJK 的字符以及 CJK 中的符号區不會被過濾.

Description:
The charaset_filter is not enabled in the Squirrel as librime-charcode
    was exclused as a standalone plug-in.
So a lua filter would be helpful to filter the frequently used
    characters (GB2312 + 常用國字標準字體表 + other characters).

版本：
20221001: 使用遍歷法寫成.
20230418: 使用集合法重寫代碼,大幅度提升運行效率,不再有卡頓現象.
20240107: 更改判斷邏輯.詞語中只要有一個字符在常用字符集内,則提高詞語
          整體優先級.此前,詞語中的所有字符都必須在常用字符集内纔會優先.
20240407: 只判斷長度爲 1 到 10 的候選項.
20240512: 重構代碼.將核心函數寫入 yuhao_core.lua 文件.將常用字符集寫
          入 yuhao_charset.lua 文件.增加一項判斷: 始終不過濾非 CJK 字符.
          增加常用繁簡字符集和通規字符集.
20240807: 重構並加入常用字前置代碼.
20240819: 前置常用漢字功能只對 CJK 内的漢字生效.
20240820: 前置常用漢字功能只在輸入爲四碼時方纔生效.
20240908: 加入前置極常用繁簡漢字功能.
20250429: 加入前置簡化漢字或傳統漢字功能.
          現在,開啟輸入預測時,常用字前置功能會跳過預測候選項,對精確匹配字詞進行
          排序.因此上,前置功能在輸入不足四碼時也能生效,並且不會造成卡頓.
20250712: 當輸入前綴是'z`, '/', 或 '`' 時,不過濾候選項.因爲它们分别引導了
          反查,特殊符號輸入,精確造詞等功能.
          過濾通規字和通規繁體字時,進行更嚴格的判斷.
20250906: 常用字過濾時使用泛 CJK 區塊的定義, 過濾更加嚴格.
20250921: 前置各個字集時,保證其他繁簡常用字處於第二優先狀態.
------------------------------------------------------------------------
]]

local core = require("yuhao.yuhao_core")
local yuhao_charsets = require("yuhao.yuhao_charsets")
local set_of_ubiquitous_chars = core.set_from_str(yuhao_charsets.ubiquitous)
local set_of_common_chars = core.set_from_str(yuhao_charsets.common)
local set_of_tonggui_chars = core.set_from_str(yuhao_charsets.tonggui)
local set_of_harmonic_chars = core.set_from_str(yuhao_charsets.harmonic)

--- 前置器
local function yuhao_charset_prioritizer(input, env, option, charset)
    local switch_on = env.engine.context:get_option(option)
    local chars_of_low_priority = {}
    local chars_of_middle_priority = {}
    local skip = false
    for cand in input:iter() do
        if skip then
            yield(cand)
        else
            if cand.type == "completion" then
                -- 遇到第一個預測的候選項,則彈出已存的後置字詞
                for _, postponed_cand in ipairs(chars_of_low_priority) do
                    yield(postponed_cand)
                end
                -- 彈出本詞
                yield(cand)
                -- 修改狀態器
                skip = true
            else
                local is_charset_or_not_cjk = core.string_is_in_set(cand.text, charset)
                local is_common_or_not_cjk = core.string_is_in_set(cand.text, set_of_common_chars)
                -- 兩種情況直接顯示字符: (1) 在字符集中 (2) 過濾器關閉
                if is_charset_or_not_cjk or not switch_on then
                    yield(cand)
                -- 將其他常用字儲存起來
                elseif is_common_or_not_cjk or not switch_on then
                    table.insert(chars_of_middle_priority, cand)
                -- 將低優先級字儲存起來
                else
                    table.insert(chars_of_low_priority, cand)
                end
            end
        end
    end
    if not skip then
        -- 説明没有遇到預測的候選項,需要在此處彈出已存的後置字詞
        for _, postponed_cand in ipairs(chars_of_middle_priority) do
            yield(postponed_cand)
        end
        for _, postponed_cand in ipairs(chars_of_low_priority) do
            yield(postponed_cand)
        end
    end
end

--- 前置極常用繁簡漢字
local function yuhao_charset_prioritizer_ubiquitous(input, env)
    yuhao_charset_prioritizer(input, env, "yuhao_charset_prioritizer_ubiquitous", set_of_ubiquitous_chars)
end

--- 前置常用繁簡漢字
local function yuhao_charset_prioritizer_common(input, env)
    yuhao_charset_prioritizer(input, env, "yuhao_charset_prioritizer_common", set_of_common_chars)
end

--- 前置常用簡化漢字
local function yuhao_charset_prioritizer_tonggui(input, env)
    yuhao_charset_prioritizer(input, env, "yuhao_charset_prioritizer_tonggui", set_of_tonggui_chars)
end

--- 前置常用傳統漢字
local function yuhao_charset_prioritizer_harmonic(input, env)
    yuhao_charset_prioritizer(input, env, "yuhao_charset_prioritizer_harmonic", set_of_harmonic_chars)
end

local function yuhao_charset_filter_common(input, env)
    if env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
        return
    end
    local switch_on = env.engine.context:get_option("yuhao_charset_filter_common")
    for cand in input:iter() do
        local is_charset_or_not_cjk = core.string_is_in_charset_or_not_in_pan_cjk(cand.text, set_of_common_chars)
        -- 三種情況顯示字符: (1) 常用 (2) 非 CJK (3) 過濾器關閉
        if is_charset_or_not_cjk or not switch_on then
            yield(cand)
        end
    end
end

local function yuhao_charset_filter_tonggui(input, env)
    if env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
        return
    end
    local switch_on = env.engine.context:get_option("yuhao_charset_filter_tonggui")
    for cand in input:iter() do
        local is_in_charset = core.string_is_in_set(cand.text, set_of_tonggui_chars)
        local is_core_punc = core.string_is_in_unicode_blocks(cand.text, core.cjk_punc_blocks)
        local is_charset_or_is_core_punc = is_in_charset or is_core_punc
        -- 三種情況顯示字符: (1) 通規傳統字 (2) 核心標點符號 (3) 過濾器關閉
        if is_charset_or_is_core_punc or not switch_on then
            yield(cand)
        end
    end
end

local function yuhao_charset_filter_harmonic(input, env)
    if env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
        return
    end
    local switch_on = env.engine.context:get_option("yuhao_charset_filter_harmonic")
    for cand in input:iter() do
        local is_in_charset = core.string_is_in_set(cand.text, set_of_harmonic_chars)
        local is_core_punc = core.string_is_in_unicode_blocks(cand.text, core.cjk_punc_blocks)
        local is_charset_or_is_core_punc = is_in_charset or is_core_punc
        -- 三種情況顯示字符: (1) 通規傳統字 (2) 核心標點符號 (3) 過濾器關閉
        if is_charset_or_is_core_punc or not switch_on then
            yield(cand)
        end
    end
end

return {
    yuhao_charset_prioritizer_ubiquitous = yuhao_charset_prioritizer_ubiquitous,
    yuhao_charset_prioritizer_common = yuhao_charset_prioritizer_common,
    yuhao_charset_prioritizer_tonggui = yuhao_charset_prioritizer_tonggui,
    yuhao_charset_prioritizer_harmonic = yuhao_charset_prioritizer_harmonic,
    yuhao_charset_filter_common = yuhao_charset_filter_common,
    yuhao_charset_filter_tonggui = yuhao_charset_filter_tonggui,
    yuhao_charset_filter_harmonic = yuhao_charset_filter_harmonic,
}
