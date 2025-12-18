--[[
-- Name: yuhao_auto_select_postponed.lua
-- 名稱: 前綴碼延遲自動上屏候選項
-- Version: 20251217
-- Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- 版權聲明：
-- 專爲宇浩系列輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
實現延遲自動頂字上屏功能.
當前編碼達到最大碼長或以韻碼(aeiou)結尾時，下一碼自動頂出首選項.

版本:
20250820: 初版,實現延遲自動頂字上屏功能.
20251217: 可以指定最大碼長,默認5碼.
---------------------------
--]]

local this = {}

function this.init(env)
    local config = env.engine.schema.config
    env.max_code_length = config:get_int("schema_name/max_code_length") or 5
end

local kRejected = 0 -- 字符不上屏，結束 processors 流程
local kAccepted = 1 -- 字符上屏，結束 processors 流程
local kNoop = 2     -- 字符不上屏，交給下一個 processor


---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
    local context = env.engine.context
    -- 只接受單個字母鍵按下事件，忽略修飾鍵
    if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:shift() or key_event:caps() then
        return kNoop
    end

    -- 只處理字母鍵
    if key_event.keycode < ('a'):byte() or key_event.keycode > ('z'):byte() then
        return kNoop
    end

    local input = context.input

    -- 檢查當前輸入是否為空
    if input == "" then
        return kNoop
    end

    -- 檢查編碼區是否達到最大碼長或者尾碼是否為韻碼(aeiou)
    local last_char = input:sub(-1)
    if (string.len(input) == env.max_code_length) or last_char:match("[aeiou]") then
        -- 取出輸入中當前正在翻譯的一部分
        local segment = context.composition:toSegmentation():back()
        if not segment then
            return kNoop
        end

        -- 獲取首選候選項
        local first_candidate = segment:get_candidate_at(0)
        if first_candidate then
            -- 自動選擇首選項 (模擬按下數字鍵 '1')
            env.engine:process_key(KeyEvent('1'))
            return kNoop
        end
    end

    return 2
end

return this