--[[
-- Name: yuhao_hide_space_candidates.lua
-- 名稱: 過濾空格上屏簡碼字
-- Version: 20251217
-- Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- 版權聲明：
-- 專爲宇浩系列輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
本開關開啟後,所有的空格上屏簡碼字將全部被屏蔽.

版本:
20250810: 初版.
20251217: 可以指定最大碼長,默認5碼.
---------------------------
--]]

local this = {}

function this.init(env)
    local config = env.engine.schema.config
    env.max_code_length = config:get_int("schema_name/max_code_length") or 5
end

function this.func(input, env)
    local context = env.engine.context
    if not context:get_option("yuhao_hide_space_candidates") then
        for cand in input:iter() do
            yield(cand)
        end
    elseif env.engine.context.input:match("^[z/`]") then
        for cand in input:iter() do
            yield(cand)
        end
    else
        if string.len(env.engine.context.input) < env.max_code_length then
            for cand in input:iter() do
                if cand.type == "punct" then
                    yield(cand)
                elseif cand.type ~= "completion" then
                    if env.engine.context.input:match("[aeiou]$") then
                        yield(cand)
                    end
                else
                    yield(cand)
                end
            end
        else
            for cand in input:iter() do
                yield(cand)
            end
        end
    end
end

return this