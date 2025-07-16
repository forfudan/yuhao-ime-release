--[[
-- Name: yuhao_unicode_input.lua
-- 名稱: Unicode 輸入
-- Version: 20250716
-- Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
-- Github: https://github.com/forFudan/
-- Purpose: 處理 Unicode 輸入
-- 版權聲明：
-- 專爲宇浩輸入法製作 <https://shurufa.app>
-- 轉載請保留作者名和出處
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

介紹:
這個 lua 腳本處理 Unicode 輸入,允許用戶輸入 Unicode 字符的十六進制編碼.
引導符號是 '='. 用户可以輸入鍵盤上兩排字母來輸入 Unicode 字符.
例如,輸入 'q' 將輸入 '1', 輸入 'w' 將輸入 '2', 輸入 'a' 將輸入 'a', 依此類推.

版本:
20250716: 初版.
---------------------------
--]]

local function filter(input, env)
    local input_text = env.engine.context.input
    if input_text:match("^%=$") then
        yield(Candidate("unicode", 1, 5, "=", "等於號"))
    elseif input_text:match("^%=[qwertyuiopasdfgh]+") then
        local mapping = {
            q = "1", w = "2", e = "3", r = "4", t = "5", 
            y = "6", u = "7", i = "8", o = "9", p = "0",
            a = "a", s = "b", d = "c", f = "d", g = "e", h = "f"
        }
        local raw_unicode = input_text:sub(2)
        local valid_unicode = raw_unicode:gsub(".", function(char)
            return mapping[char] or char
        end)
        local unicode_str = string.format("0x%s", valid_unicode)
        local code = tonumber(unicode_str or "")
        local space = utf8.codepoint(" ")
        local character = utf8.char(code or space)
        yield(Candidate("unicode", 1, 5, character, "Unicode 輸入"))
        yield(Candidate("unicode", 1, 5, unicode_str, "Unicode 十六進制"))
        yield(Candidate("unicode", 1, 5, code, "Unicode 十進制"))
    else
        -- If the input is not a valid unicode code point, we yield all candidates.
        for cand in input:iter() do
            yield(cand)
        end
    end
end

return filter