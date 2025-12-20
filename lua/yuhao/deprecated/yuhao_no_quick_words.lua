--[[
Name: yuhao_no_quick_words.lua
名稱: 簡碼詞開關
Version: 20240516
Author: forFudan 朱宇浩 <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
Purpose: 當用户輸入非全碼時,不出簡碼詞語,只出簡碼單字.
------------------------------------------------------------------------
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
------------------------------------------------------------------------
switches 添加狀態:
    - name: yuhao_no_quick_words
    reset: 0
    states: [有簡碼詞, 無簡碼詞]
engine/filters 添加:
    - lua_filter@*yuhao.yuhao_no_quick_words
------------------------------------------------------------------------
]]

local core = require("yuhao.yuhao_core")

local function filter(input, env)
    local option = env.engine.context:get_option("yuhao_no_quick_words")
    local length_of_input = string.len(env.engine.context.input)
    for cand in input:iter() do
        -- Yield if
        -- (1) option is 0 or
        -- (2) code length is 4
        -- (3) char length is 1
        if option or (length_of_input == 4) or (utf8.len(cand.text) == 1) then
            yield(cand)
        end
    end
end

return filter
