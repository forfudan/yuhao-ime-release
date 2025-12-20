--[[
-- Name: yuhao_autocompletion_conditional_filter.lua
-- 名稱: 部分條件下,預測剩餘編碼爲一的候選項
-- Version: 20250714
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 只顯示剩餘編碼爲一的預測候選項
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
這個 lua 腳本會在輸入編碼長度小於等於 2 時,過濾掉所有需要再打兩碼及以上的預測項,
只保留需要再打一碼的預測項.同時,它必須是末碼爲韻碼(aeiou)的常用單字.
輸入編碼長度等於 3 或 4 時,顯示所有單字候選項,且根據剩餘編碼和常用字進行排序.

本過濾器對於宇浩·日月這種設置了簡碼的前綴碼方案非常有用.
前綴碼方案,簡碼往往設置爲全碼的前幾碼加上最後的韻碼.因此韻碼可看作是一種上屏碼.
本過濾器開啓後, RIME 只提示再按一下韻碼就能上屏的字,而忽略其他的預測候選項.
用户既能瞭解哪些字是可以直接上屏的,又能避免過多的預測候選項造成視覺干擾.
由於韻碼只有五個,因此預測候選最多只有五個(~a,~e,~i,~o,~u).

版本:
20250712: 初版.
20250713: 修改過濾條件: 當輸入編碼長度等於 3 或 4 時,顯示所有單字候選項,
          且根據剩餘編碼和常用字進行排序.
20250715: 修復bug:當一個字同時設置了非韻碼簡碼和韻碼簡碼時,如果非韻碼尾碼靠前,
          則RIME的後選項的備註會提示該非韻碼,導致本過濾器將其過濾.
          修復後,會強制將此後選項的備註由非韻碼改成韻碼.
20250809: 爲空格上屏的候選項添加備註,以便用户及時區分空格上屏簡碼和韻碼上屏簡碼.
20250810: 爲候選項添加備註,以便用户及時區分頂字上屏編碼.
          當編碼小於4時,也提示韻碼上屏簡詞.
          當編碼小於3時,也提示韻碼上屏的生僻字,但置於常用字之後.
20250811: 五碼首選項備註改作「頂屏」.
20251213: 爲第二個候選項備註「分號」.
---------------------------
--]]

-- Read the required modules
local core = require("yuhao.yuhao_core")
local yuhao_charsets = require("yuhao.yuhao_charsets")
local set_of_ubiquitous_chars = core.set_from_str(yuhao_charsets.ubiquitous)
local set_of_common_chars = core.set_from_str(yuhao_charsets.common)

local function init(env)
    local config = env.engine.schema.config
    local code_rvdb = config:get_string("schema_name/code")
    env.code_rvdb = ReverseDb("build/" .. code_rvdb .. ".reverse.bin")
    env.mem = Memory(env.engine, Schema(code_rvdb))
end

local function is_one_code_and_is_vowel(cand, env)
    local length_of_input = string.len(env.engine.context.input)
    local character = cand.text
    local codes_of_character = env.code_rvdb:lookup(character)
    -- env.code_rvdb:lookup() returns space-separated codes.
    -- So we do a loop here to check if any leading n-1 code matches the input.
    local is_one_code = false
    local is_vowel = false
    local vowel = nil
    for code in codes_of_character:gmatch("%S+") do
        if (length_of_input == string.len(code) - 1) and (code:sub(1, length_of_input) == env.engine.context.input) then
            if code:match("[aeiou]$") then
                -- is one code and is vowel
                is_one_code = true
                is_vowel = true
                vowel = code:sub(-1)
            else
                -- is one code but not vowel
                is_one_code = true
            end
        end
    end
    return is_one_code, is_vowel, vowel
end

local function filter(input, env)
    local context = env.engine.context
    if not context:get_option("yuhao_autocompletion_conditional_filter") then
        for cand in input:iter() do
            yield(cand)
        end
    elseif env.engine.context.input:match("^[z/`]") then
        for cand in input:iter() do
            yield(cand)
        end
    else
        if string.len(env.engine.context.input) == 5 then
            -- 如果輸入長度等於 5,則顯示全部單字候選項
            local index_of_cand = 0
            for cand in input:iter() do
                if index_of_cand == 0 then
                    -- 如果是第一個候選項,則顯示"頂屏"
                    yield(Candidate(cand.type, cand.start, cand._end, cand.text, "頂屏"))
                elseif index_of_cand == 1 then
                    -- 如果是第二個候選項,則顯示"分號"
                    yield(Candidate(cand.type, cand.start, cand._end, cand.text, "分號"))
                else
                    yield(cand)
                end
                index_of_cand = index_of_cand + 1
            end
        elseif string.len(env.engine.context.input) == 4 then
            -- 如果輸入長度等於 4,則顯示全部單字候選項
            local table_common_chars = {}
            local table_uncommon_chars = {}
            local index_of_cand = 0
            for cand in input:iter() do
                if cand.type ~= "completion" then
                    -- 非預測候選項,直接顯示
                    if index_of_cand == 0 then
                        if env.engine.context.input:match("[aeiou]$") then
                            -- 如果輸入末碼是韻碼,則顯示"頂屏"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "頂屏"))
                        else
                            -- 如果是第一個候選項,則顯示"空格"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "空格"))
                        end
                    elseif index_of_cand == 1 then
                        -- 如果是第二個候選項,則顯示"分號"
                        yield(Candidate(cand.type, cand.start, cand._end, cand.text, "分號"))
                    else
                        yield(cand)
                    end
                    index_of_cand = index_of_cand + 1
                else
                    -- elseif utf8.len(cand.text) <= 2 then
                    if core.string_is_in_set(cand.text, set_of_common_chars) then
                        table.insert(table_common_chars, cand)
                    else
                        table.insert(table_uncommon_chars, cand)
                    end
                end
            end
            for _, cand in ipairs(table_common_chars) do
                yield(cand)
            end
            for _, cand in ipairs(table_uncommon_chars) do
                yield(cand)
            end
        elseif string.len(env.engine.context.input) == 3 then
            -- 如果輸入長度等於 3,則顯示全部單字候選項
            local table_one_code_common_chars = {}
            local table_one_code_uncommon_chars = {}
            local table_other_common_chars = {}
            local table_other_uncommon_chars = {}
            local table_one_code_words = {}
            local index_of_cand = 0
            for cand in input:iter() do
                local is_one_code, _, _ = is_one_code_and_is_vowel(cand, env)
                if cand.type ~= "completion" then
                    -- 非預測候選項,直接顯示
                    if index_of_cand == 0 then
                        if env.engine.context.input:match("[aeiou]$") then
                            -- 如果輸入末碼是韻碼,則顯示"頂屏"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "頂屏"))
                        else
                            -- 如果是第一個候選項,則顯示"空格"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "空格"))
                        end
                    elseif index_of_cand == 1 then
                        -- 如果是第二個候選項,則顯示"分號"
                        yield(Candidate(cand.type, cand.start, cand._end, cand.text, "分號"))
                    else
                        yield(cand)
                    end
                    index_of_cand = index_of_cand + 1
                elseif utf8.len(cand.text) == 1 then
                    if is_one_code then
                        if core.string_is_in_set(cand.text, set_of_common_chars) then
                            table.insert(table_one_code_common_chars, cand)
                        else
                            table.insert(table_one_code_uncommon_chars, cand)
                        end
                    else
                        if core.string_is_in_set(cand.text, set_of_common_chars) then
                            table.insert(table_other_common_chars, cand)
                        else
                            table.insert(table_other_uncommon_chars, cand)
                        end
                    end
                else
                    if is_one_code then
                        -- 還需要輸入一碼的詞
                        table.insert(table_one_code_words, cand)
                    end
                end
            end
            for _, cand in ipairs(table_one_code_common_chars) do
                yield(cand)
            end
            for _, cand in ipairs(table_one_code_words) do
                yield(cand)
            end
            for _, cand in ipairs(table_one_code_uncommon_chars) do
                yield(cand)
            end
            for _, cand in ipairs(table_other_common_chars) do
                yield(cand)
            end
            for _, cand in ipairs(table_other_uncommon_chars) do
                yield(cand)
            end
        else
            -- 如果輸入長度小於 3
            local index_of_cand = 0
            local table_one_code_uncommon_chars = {}
            for cand in input:iter() do
                if cand.type ~= "completion" then
                    -- 非預測候選項,直接顯示
                    if index_of_cand == 0 then
                        if env.engine.context.input:match("[aeiou]$") then
                            -- 如果輸入末碼是韻碼,則顯示"頂屏"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "頂屏"))
                        else
                            -- 如果是第一個候選項,則顯示"空格"
                            yield(Candidate(cand.type, cand.start, cand._end, cand.text, "空格"))
                        end
                    elseif index_of_cand == 1 then
                        -- 如果是第二個候選項,則顯示"分號"
                        yield(Candidate(cand.type, cand.start, cand._end, cand.text, "分號"))
                    else
                        yield(cand)
                    end
                    index_of_cand = index_of_cand + 1
                else
                    -- 只顯示剩餘編碼爲一的預測候選項
                    -- 只顯示剩餘編碼爲韻碼的預測候選項
                    --- 只顯示單字
                    --- 只顯示極常用字
                    local is_one_code, is_vowel, vowel = is_one_code_and_is_vowel(cand, env)
                    if is_one_code then
                        if is_vowel then
                            if (utf8.len(cand.text) == 1) then
                                if core.string_is_in_set(cand.text, set_of_ubiquitous_chars) then
                                    -- 如果預測項的備註是非韻碼,則強制將其改爲韻碼
                                    yield(Candidate(cand.type, cand.start, cand._end, cand.text, vowel))
                                else
                                    table.insert(table_one_code_uncommon_chars, cand)
                                end
                            end
                            if (utf8.len(cand.text) > 1) then
                                -- 簡碼詞
                                yield(Candidate(cand.type, cand.start, cand._end, cand.text, vowel))
                            end
                        end
                    else
                        -- 如果預測項進入需要再打兩碼及以上的情況
                        -- 直接跳過剩下所有的預測候選項
                        break
                    end
                end
            end
            for _, cand in ipairs(table_one_code_uncommon_chars) do
                yield(cand)
            end
        end
    end
end

return {
    init = init,
    func = filter
}
