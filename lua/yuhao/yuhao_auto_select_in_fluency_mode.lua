--[[
Name: yuhao_auto_select_in_fluency_mode.lua
名稱: 自動選擇候選項
Version: 20240510
Author: 譚淞宸 <https://github.com/tansongchen>
Purpose: 對於過長的整句輸入,當字數超過一定數量時,下一擊自動選擇第二候選
    項.這個插件可使得第一候選項的字數不超過一定數量(默認爲8).
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
版本：
20240510, 譚淞宸: 當字數超過一定數量時,下一擊自動選擇第二候選項.
20240514, 朱宇浩: 注意到有時第二選項並不是第一選項的頭幾個字,用户可能在
    不覺中上屏了其他的字.因此進行一個判斷，只有當第二選項是第一個選項的
    頭幾個字的時候纔會選擇上屏.用户可以指定候選區最多顯示的漢字數.
20240517, 朱宇浩: 續上.第一選項有時是第三候選,因此加一個判斷上屏之.
---------------------------------------
]]

local core = require("yuhao.yuhao_core")

local this = {}

function this.init(env)
    local config = env.engine.schema.config
    env.max_chars = config:get_int('yuhao_auto_select_in_fluency_mode/max_chars') or 8
end

local kNoop = 2

function startswith(text, start)
    return text:sub(1, #start) == start
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
    local context = env.engine.context
    -- 只接受单个字母键
    if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:shift() or key_event:caps() then
        return kNoop
    end
    if key_event.keycode < ('a'):byte() or key_event.keycode > ('z'):byte() then
        return kNoop
    end
    -- 取出输入中当前正在翻译的一部分
    local segment = context.composition:toSegmentation():back();
    if not segment then
        return kNoop
    end
    local first_candidate = segment:get_candidate_at(0)
    local second_candidate = segment:get_candidate_at(1)
    local third_candidate = segment:get_candidate_at(2)
    if not first_candidate or not second_candidate then
        return kNoop
    end
    if utf8.len(first_candidate.text) < env.max_chars then
        return kNoop
    end
    if core.string_starts_with(first_candidate.text, second_candidate.text) then
        env.engine:process_key(KeyEvent('2'))
        return kNoop
    end
    if core.string_starts_with(first_candidate.text, third_candidate.text) then
        env.engine:process_key(KeyEvent('3'))
        return kNoop
    end
    return kNoop
end

return this
