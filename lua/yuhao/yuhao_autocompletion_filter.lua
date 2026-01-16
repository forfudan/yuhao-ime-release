--[[
-- Name: yuhao_autocompletion_filter.lua
-- 名稱: 輸入預測開關
-- Version: 20230901
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 通過開關打開或關閉輸入預測，從而不需要修改 schema.yaml
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International

-- 版本:
-- 20230901: 初版.
-- 20260116: 不對非 a-z 開頭的預測候選項進行過濾.
---------------------------
--]]

local function filter(input, env)
    if not env.engine.context:get_option("yuhao_autocompletion_filter") then
        -- If the option is disabled, we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
    elseif env.engine.context.input:match("^[^a-z]") then
        -- If the input starts with a non a-z character,
        -- we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
    else
        for cand in input:iter() do
            -- If the option is on and the input starts with a-z,
            -- the filter will work
            if cand.type == "completion" then
                -- Do not yield completion candidates.
                -- Once we reach the completion region,
                -- we stop yielding further candidates.
                return
            else
                yield(cand)
            end
        end
    end
end

return { func = filter }