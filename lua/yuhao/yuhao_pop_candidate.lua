--[[
-- Name: yuhao_pop_candidate.lua
-- 名稱: 頂出候選項
-- Version: 20250722
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 出現韻碼時,下一碼頂出前序首位候選項.
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

版本:
20250722: 初版.
---------------------------
--]]

local function filter(input, env)

    if (env.engine.context.input:match("^%L")) then
        for cand in input:iter() do
            yield(cand)
        end
        return

    elseif env.engine.context.input:match("^[z/`]") then
        -- If the input starts with 'z', '/', or '`', we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
        return

    elseif env.engine.context.input:match("[aeiou]%l$") then
        -- Any letter following a vowel is considered a new character.
        return

    else
        for cand in input:iter() do
            yield(cand)
        end
        return
    end
end

return {
    func = filter
}
