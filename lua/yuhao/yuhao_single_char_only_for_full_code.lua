--[[
Name: yuhao_single_char_only_for_full_code.lua
名稱: 全碼詞語過濾器
Version: 20250819
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
---------------------------
]]

local core = require("yuhao.yuhao_core")

local function init(env)
    local config = env.engine.schema.config
    local code_rvdb = config:get_string("schema_name/code")
    env.code_rvdb = ReverseDb("build/" .. code_rvdb .. ".reverse.bin")
    env.mem = Memory(env.engine, Schema(code_rvdb))
end

-- 檢查候選項是否是簡碼
-- 如果該候選項存在一個更長的碼，則認爲它是簡碼
local function is_short_code(cand, env)
    local length_of_input = string.len(env.engine.context.input)
    local codes_of_candidates = env.code_rvdb:lookup(cand.text)
    local is_short = false
    for code in codes_of_candidates:gmatch("%S+") do
        if string.len(code) > length_of_input then
            is_short = true
            break
        end
    end
    return is_short
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
            local cand_genuine = cand:get_genuine()
            if cand_genuine.type == 'completion' then
                -- 預測候選項不顯示詞語
                if core.is_single_char(cand.text) then
                    yield(cand)
                end
            else
                -- 精確匹配顯示簡詞
                if core.is_single_char(cand.text) or is_short_code(cand, env) then
                    yield(cand)
                end
            end
        end
    end
end

return { init = init, func = filter }
