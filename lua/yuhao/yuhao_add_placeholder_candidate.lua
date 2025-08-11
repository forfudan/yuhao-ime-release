--[[
-- Name: yuhao_add_placeholder_candidate.lua
-- 名稱: 添加佔位符候選項
-- Version: 20250712
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 非五碼時,爲單一候選項添加一個佔位符候選項,防止自動上屏
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
滿足一下情況時,添加一個佔位符候選項:
1. 當前候選欄中的候選項數量爲 0 或 1.
2. 當前唯一候選項不以 aeiou 結尾且輸入編碼低於五.

版本:
20250712: 初版.
20250810: 如果沒有空格上屏的簡碼字,則不需要添加佔位符候選項.
---------------------------
--]]

local function filter(input, env)

    if env.engine.context:get_option("yuhao_hide_space_candidates") and env.engine.context:get_option("yuhao_autocompletion_filter") then
        -- If there is no space candidates and no autocompletion.
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    if (env.engine.context.input:match("^%L")) then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    if env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    if env.engine.context.input:match("[aeiou]%l$") then
        -- Any letter following a vowel is considered a new character.
        return
    end

    -- Count the number of candidates in the input.
    -- If 0, no candidates; if 1, only one candidate; if 2, more than one candidate.
    -- The iteration will consume the candidate, so we store the first and second candidates.
    local first_cand = nil
    local second_cand = nil
    local number_of_candidates = 0
    for cand in input:iter() do
        number_of_candidates = number_of_candidates + 1
        if number_of_candidates == 1 then
            first_cand = cand
        end
        if number_of_candidates == 2 then
            second_cand = cand
            break
        end
    end

    local input_text = env.engine.context.input
    local length_of_input = string.len(input_text)
    local placeholder_cand = Candidate("placeholder", 1, 5, "", "宇浩·日月")

    if number_of_candidates == 0 then
        --- If there is no candidates.
        if env.engine.context.input:match("[aeiou]$") then
            -- If the the last letter is a vowel,
            -- we do not add a placeholder candidate,
            -- Example: `wkk` = 俱 `u` = 不
            -- `wkku` should return nothing so that RIME will pop out `wkk`
            -- and left `u` in the preedit region
            return
        elseif length_of_input >= 5 then
            -- If the length of input reaches 5, we do not add a placeholder candidate.
            -- Example: `wkkgu` = 個
            -- 可以直接上屏
            return
        else
            -- If there is no candidates and the input length is less than 5,
            -- we need to prevent auto-selection.
            -- Example: `hzlll` = 邊
            -- `hzl` and `hzll` have no candidates, we should add a placeholder
            -- so that `hz` = 自己 will not be auto-selected.
            yield(placeholder_cand)
        end
    elseif number_of_candidates == 1 then
        -- If there is only one candidate, first yield it
        yield(first_cand)
        -- Then, check if the input ends with a vowel or the length of input is 5.
        -- If not, add a placeholder candidate.
        local ends_with_vowel = input_text:match("[aeiou]$")
        if not (ends_with_vowel or (length_of_input == 5)) then
            yield(placeholder_cand)
        end
    else
        -- If there are multiple candidates, yield them as usual.
        yield(first_cand)
        yield(second_cand)
        for cand in input:iter() do
            yield(cand)
        end
    end
end

return {
    func = filter
}
