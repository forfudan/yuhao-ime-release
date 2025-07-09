--[[
Name: yuhao_single_char_only_for_full_code.lua
名稱: 全碼單字過濾
Version: 20250602
Author: 朱宇浩 <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
Purpose: 當用户輸入四碼及以上時,只出單字,不出詞語.適合單字簡詞黨.
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
-------------------------------------

介紹:
對於單字黨而言,有時候也希望能够通過輸入簡碼詞語提高打字速度.
本腳本會對碼長進行一次判斷.
當用户輸入不到四碼時,同時出單字和詞語.
當用户輸入四碼及以上時,只出單字,不出詞語.

Description:
Only show single characters when users typing full code (>= 4 letters.)
Show both single characters and words when users typing 1 to 3 letters.

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
---------------------------
]]

local function filter(input, env)

    local option = env.engine.context:get_option("yuhao_single_char_only_for_full_code")
    local length_of_input = string.len(env.engine.context.input)
    for cand in input:iter() do
        local cand_genuine = cand:get_genuine()
        if cand_genuine.type == 'completion' then
            if not (option and (utf8.len(cand.text) > 1)) then
                yield(cand)
            end
        else
            -- If option is 1, code length >= 4, char len is not 1, do not yield candicate.
            if not (option and (utf8.len(cand.text) > 1) and (length_of_input >= 4)) then
                yield(cand)
            end
        end
    end
end

return filter
