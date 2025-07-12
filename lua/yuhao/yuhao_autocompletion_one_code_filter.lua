--[[
-- Name: yuhao_autocompletion_one_code_filter.lua
-- 名稱: 剩餘編碼爲一時進行輸入預測
-- Version: 20250712
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 只顯示剩餘編碼爲一的預測候選項
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
這個 lua 腳本會過濾掉所有需要再打兩碼及以上的預測項,只保留需要再打一碼的預測項.
同時,它必須是末碼爲韻碼(aeiou)的常用單字.

本過濾器對於宇浩·日月這種設置了簡碼的前綴碼方案非常有用.
前綴碼方案,簡碼往往設置爲全碼的前幾碼加上最後的韻碼.因此韻碼可看作是一種上屏碼.
本過濾器開啓後, RIME 只提示再按一下韻碼就能上屏的字,而忽略其他的預測候選項.
用户既能瞭解哪些字是可以直接上屏的,又能避免過多的預測候選項造成視覺干擾.
由於韻碼只有五個,因此預測候選最多只有五個(~a,~e,~i,~o,~u).

版本:
20250712: 初版.
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
    -- So we do a loop here to check if any code matches the input length + 1.
    for code in codes_of_character:gmatch("%S+") do
        if length_of_input == string.len(code) - 1 then
            if code:match("[aeiou]$") then
                -- is one code and is vowel
                return true, true
            else
                -- is one code but not vowel
                return true, false
            end
        end
    end
    return false, false
end

local function filter(input, env)
    local context = env.engine.context
    if not context:get_option("yuhao_autocompletion_one_code_filter") then
        for cand in input:iter() do
            yield(cand)
        end
    else
        for cand in input:iter() do
            if cand.type ~= "completion" then
                yield(cand)
            else
                local is_one_code, is_vowel = is_one_code_and_is_vowel(cand, env)
                if is_one_code then
                    -- 只顯示剩餘編碼爲一的預測候選項
                    if is_vowel then
                        -- 只顯示剩餘編碼爲韻碼的預測候選項
                        if utf8.len(cand.text) == 1 then
                            --- 只顯示單字
                            if core.string_is_in_set(cand.text, set_of_ubiquitous_chars) then
                                --- 只顯示常用字
                                yield(cand)
                            end
                        end
                    end
                else
                    -- If the candidate begins to be two-code autocompletion,
                    -- we skip all candidates from it to save processing time.
                    return
                end
            end
        end
    end
end

return {
    init = init,
    func = filter
}
