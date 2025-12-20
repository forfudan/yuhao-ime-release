--[[
-- Name: yuhao_popper_hints.lua
-- 名稱: 提示韻碼上屏字
-- Version: 20251220
-- Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 提示韻碼上屏字
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
這個 lua 腳本會根據輸入編碼長度對預測候選項進行排序:
- 輸入編碼長度小於等於 2 時,優先顯示剩餘編碼爲一且末碼爲韻碼(aeiou)的極常用單字,
  然後顯示剩餘編碼爲一的其他候選項(包括簡碼詞、非韻碼結尾字、非極常用字),
  最後顯示所有需要再打兩碼及以上的預測候選項.
- 輸入編碼長度等於 3 時,按剩餘編碼和常用字進行排序,優先顯示剩餘編碼爲一的候選項.
- 輸入編碼長度等於 4 時,顯示所有單字候選項,預測候選項按常用字排序.

本過濾器對於宇浩·日月輸入法這種設置了簡碼的前綴碼方案非常有用.
前綴碼方案,簡碼往往設置爲全碼的前幾碼加上最後的韻碼.因此韻碼可看作是一種上屏碼.
本過濾器開啓後, RIME 會優先提示再按一下韻碼就能上屏的極常用字,
讓用户既能瞭解哪些字可以直接用韻碼上屏,又能在需要時查看其他候選項.
由於韻碼只有五個,因此優先顯示的韻碼候選最多只有五個(~a,~e,~i,~o,~u).
本過濾器還能在出現多個後選項的時候適當提醒用戶首選項是頂屏還是空格上屏.

版本:
20250712: 初版.
20250713: 修改過濾條件: 當輸入編碼長度等於 3 或 4 時,顯示所有單字候選項,
          且根據剩餘編碼和常用字進行排序.
20250715: 修復bug:當一個字同時設置了非韻碼簡碼和韻碼簡碼時,如果非韻碼尾碼靠前,
          則RIME的候選項的備註會提示該非韻碼,導致本過濾器將其過濾.
          修復後,會強制將此候選項的備註由非韻碼改成韻碼.
20250809: 爲空格上屏的候選項添加備註,以便用户及時區分空格上屏簡碼和韻碼上屏簡碼.
20250810: 爲候選項添加備註,以便用户及時區分頂字上屏編碼.
          當編碼小於4時,也提示韻碼上屏簡詞.
          當編碼小於3時,也提示韻碼上屏的生僻字,但置於常用字之後.
20250811: 五碼首選項備註改作「頂屏」.
20251213: 爲第二個候選項備註「分號」.
20251220: 修正單字判斷邏輯,正確支持變體選擇器.
          增加對於最大編碼長度為 4 的輸入方案的支持.
          現在,輸入編碼長度為 1 或 2 時,除了顯示剩餘編碼爲一的韻碼結尾候選項外,
          還會在後方繼續顯示其他所有的預測候選項,而非之前的完全過濾.
          韻碼提示更加明顯,備註「韻碼」+ 字母.
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
    env.max_code_length = config:get_int("schema_name/max_code_length") or 5
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
    if not context:get_option("yuhao_popper_hints") then
        for cand in input:iter() do
            yield(cand)
        end
    elseif env.engine.context.input:match("^[z/`]") then
        for cand in input:iter() do
            yield(cand)
        end
    else
        if (env.max_code_length >= 5) and (string.len(env.engine.context.input) >= 5) then
            -- 最大碼長至少為 5 且輸入長度大於等於 5
            -- 顯示全部候選項
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
            -- 輸入長度等於 4
            -- 觀察最大碼長
            if env.max_code_length >= 5 then
                -- 如果最大碼長至少為5,則顯示全部單字候選
                -- 如果非預測候選項,直接顯示
                -- 如果是預測候選項,則根據常用字表進行排序
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
                        -- 預測後選項排序
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
            else
                -- 如果最大碼長為4,則顯示全部單字候選
                -- 此時沒有預測候選項,故而不需要排序
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
            end
        elseif string.len(env.engine.context.input) == 3 then
            -- 輸入長度等於 3,則顯示全部單字候選項
            -- 如果是非預測候選項,直接顯示
            -- 如果是預測候選項,按照以下順序排序:
            --   1. 剩餘編碼爲一的常用字
            --   2. 剩餘編碼爲一的詞
            --   3. 剩餘編碼爲一的生僻字
            --   4. 其他常用字
            --   5. 其他生僻字
            local table_one_code_common_chars = {}
            local table_one_code_uncommon_chars = {}
            local table_other_common_chars = {}
            local table_other_uncommon_chars = {}
            local table_one_code_words = {}
            local table_other_words = {}  -- 用於存放剩餘編碼≥2的詞
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
                elseif core.is_single_char(cand.text) then
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
                    else
                        -- 還需要輸入兩碼及以上的詞
                        table.insert(table_other_words, cand)
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
            for _, cand in ipairs(table_other_words) do
                yield(cand)
            end
        else
            -- 輸入長度爲 1 或 2
            -- 如果是非預測候選項,直接顯示
            -- 如果是預測候選項,按照以下順序排序:
            --   1. 剩餘編碼爲一的韻碼結尾預測候選項（按 aeiou 排序）
            --   2. 剩餘編碼爲一的其他預測候選項
            --   3. 剩餘候選項
            local index_of_cand = 0
            local table_vowel_poppers = {}  -- 用於存放韻碼上屏的候選項（極常用字和簡碼詞）
            local table_one_code_other_chars = {}  -- 用於存放剩餘編碼爲一但非韻碼結尾的預測候選項
            local is_yielded = false  -- 直接顯示候選,不用任何判斷
            for cand in input:iter() do
                if is_yielded then
                    yield(cand)
                elseif cand.type ~= "completion" then
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
                    local is_one_code, is_vowel, vowel = is_one_code_and_is_vowel(cand, env)
                    if is_one_code then
                        -- 只需要再打一碼的候選區
                        if is_vowel then
                            if core.is_single_char(cand.text) then
                                if core.string_is_in_set(cand.text, set_of_ubiquitous_chars) then
                                    -- 極常用字，收集起來按韻碼排序
                                    table.insert(table_vowel_poppers, {cand = cand, vowel = vowel})
                                else
                                    table.insert(table_one_code_other_chars, cand)
                                end
                            end
                            if not core.is_single_char(cand.text) then
                                -- 簡碼詞，收集起來按韻碼排序
                                table.insert(table_vowel_poppers, {cand = cand, vowel = vowel})
                            end
                        else
                            -- 如果預測項不是韻碼結尾
                            table.insert(table_one_code_other_chars, cand)
                        end
                    else
                        -- 進入需要再打兩碼及以上的候選區
                        -- 先按韻碼順序輸出收集的韻碼候選
                        table.sort(table_vowel_poppers, function(a, b)
                            local order = {a = 1, e = 2, i = 3, o = 4, u = 5}
                            return (order[a.vowel] or 0) < (order[b.vowel] or 0)
                        end)
                        for _, item in ipairs(table_vowel_poppers) do
                            yield(Candidate(item.cand.type, item.cand.start, item.cand._end, item.cand.text, "韻碼 " .. item.vowel))
                        end
                        -- 再輸出其他收集的候選項
                        for _, _cand in ipairs(table_one_code_other_chars) do
                            yield(_cand)
                        end
                        -- 直接下來直接顯示候選,不用任何判斷
                        -- 通過 is_yielded 標誌位來節約運算
                        -- 這樣衹要顯示第一個字,後面的字就可以不用進入本邏輯
                        is_yielded = true
                        yield(cand)
                    end
                end
            end
            -- 循環結束後，如果未觸發 is_yielded，則輸出收集的候選項
            if not is_yielded then
                -- 先按韻碼順序輸出收集的韻碼候選
                table.sort(table_vowel_poppers, function(a, b)
                    local order = {a = 1, e = 2, i = 3, o = 4, u = 5}
                    return (order[a.vowel] or 0) < (order[b.vowel] or 0)
                end)
                for _, item in ipairs(table_vowel_poppers) do
                    yield(Candidate(item.cand.type, item.cand.start, item.cand._end, item.cand.text, "韻碼 " .. item.vowel))
                end
                -- 再輸出其他收集的候選項
                for _, _cand in ipairs(table_one_code_other_chars) do
                    yield(_cand)
                end
            end
        end
    end
end

return {
    init = init,
    func = filter
}
