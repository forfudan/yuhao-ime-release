--[[
-- Name: yuhao_short_code_hint.lua
-- 名稱: 全碼時提示簡碼
-- Version: 20260410
-- Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forfudan/
-- Purpose: 當用戶輸入全碼時,若該字存在長度爲 1 到 3 的簡碼,則在備註中提示簡碼.
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
當用户打出一個字的全碼時(即候選項爲精確匹配而非預測補全),
本過濾器會檢查該字是否有長度爲 1 到 3 的簡碼,
若有,則在候選項的備註區顯示「簡碼 XX」的提示,取最短的簡碼.
簡碼提示會替換掉原有的「頂屏」「空格」「分號」提示,但不會刪除其他備註内容.

版本:
20260410: 初版.
--]]

local core = require("yuhao.yuhao_core")

local function init(env)
    local config = env.engine.schema.config
    local code_rvdb = config:get_string("schema_name/code")
    env.code_rvdb = ReverseDb("build/" .. code_rvdb .. ".reverse.bin")
end

--- 查找字符的最短簡碼(長度 ≤ 3),且簡碼必須短於當前輸入長度
---@param character string 單個字符
---@param input_len number 當前輸入編碼長度
---@param env table
---@return string|nil 最短簡碼,若無則返回 nil
local function find_shortest_short_code(character, input_len, env)
    local codes_str = env.code_rvdb:lookup(character)
    if not codes_str or codes_str == "" then
        return nil
    end
    local shortest = nil
    for code in codes_str:gmatch("%S+") do
        local len = string.len(code)
        if len <= 3 and len < input_len then
            if shortest == nil or len < string.len(shortest) then
                shortest = code
            end
        end
    end
    return shortest
end

local function filter(input, env)
    local context = env.engine.context
    local input_len = string.len(context.input)
    for cand in input:iter() do
        -- 僅對非預測的單字候選項進行簡碼提示
        if cand.type ~= "completion" and core.is_single_char(cand.text) then
            local short_code = find_shortest_short_code(cand.text, input_len, env)
            if short_code then
                local hint = "簡碼 " .. short_code
                local comment = cand.comment
                if comment and comment ~= "" then
                    -- 替換掉「頂屏」「空格」「分號」提示,改爲簡碼提示
                    comment = comment:gsub("頂屏", ""):gsub("空格", ""):gsub("分號", "")
                    comment = comment:match("^%s*(.-)%s*$") or ""  -- trim
                    if comment ~= "" then
                        comment = comment .. " " .. hint
                    else
                        comment = hint
                    end
                else
                    comment = hint
                end
                local c = Candidate(cand.type, cand.start, cand._end, cand.text, comment)
                c.preedit = cand.preedit
                c.quality = cand.quality
                yield(c)
            else
                yield(cand)
            end
        else
            yield(cand)
        end
    end
end

return {
    init = init,
    func = filter
}
