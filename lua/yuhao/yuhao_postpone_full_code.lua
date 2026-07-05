-- 名稱: yuhao_postpone_full_code.lua
--
-- 原作者: Ace-Who <https://github.com/Ace-Who/rime-xuma/>
-- 原代碼介紹：
--   出现重码时，将全码匹配且有简码的「单字」「适当」后置。
--   目前的实现方式，原理适用于所有使用规则简码的形码方案。
--
-- 修改者: forFudan <https://github.com/forFudan/yuhao/>
-- 目的：條件後置已出簡的全碼單字
-- 版本: 20240430
-- 修改介紹：
--   1. 根據宇浩輸入法更新字根列表
--   2. 只後置位於候選欄第一項的全碼單字
--   3. 只後置選定漢字的全碼
-- 使用方法：
--   1. 默認情况下,只有當次選爲高頻字時方後置其對應首選.
--   2. schema 文件的 yuhao_postpone_full_code/selected_chars
--      列出了有需要後置的高頻字列表.
--   3. 此列表缺省或爲空字符串時，無條件全碼後置.
--   4. 可增添字符更改後置的範圍.
-- 參見:
--   關於條件後置請參見宇浩輸入法官網 <https://shurufa.app/>

local radstr =
"也不亡尚穴韋甲屮丌鬼巛丶户用爪石非僉巳儿酉雨乃生马电豸馬囗禺了尸丅面食寸幺瓦壬足麻齒乙骨又米冊爿末西王古讠人毛世丨止母丰自艮士合禾曰广见上灬〇𬺰𠂤缶七牛卯刀文千扌瓜阝斤風气魚衤工厶龰欠攴宀彡見丂竹罒烏目至艹𠂇二丬已方兀一木之八且臣矢乚卩鸟犬牙弓疒糸向山匚戊廴夕土田黽丷凡貝饣鱼刂大豕弋亦门巾長示片車犭耳夫羽𧘇水飛亠黑未戈小礻火㗊虎爾三车𡗗辛鬥鹵冖口手氵辰言白虫尤心入高龶臼殳舟卜走立來鹿子辶彐纟丿身贝申皿其匕乌亍皮早十日而〢歹甫羊革夂予干亥隹月己丁彳咼钅力門女川长亻乂巴夭舌九几冂金厂由鳥𫝀⺄㇂丩⺶𠕁龴⻟𫩏𠂒〣冎髟ソ𠂎㇞⼌マ釒⼓丄𣥂𡈼𡿨⻍⺂ッ卄乀丆戶⻎訁⼹𫠠⺧𠃌コ䒑𰃦⺮氺卝戸匸𰁜⼁𩙿𠃊习乜忄𭕄㇍兀㐄𠂊𠥓勹冫丱乁𰀁𤣩爫⼅㇇⼂廾㇣㇈⺈𠘧𠀎𥫗㔾㇕㇀龷⺆凵Γ𠂉𫶧㇜耂ス㇒𦥑糹𡭔⺼攵⼃𰆊飠𠃎ユ⺊𥝌㇏⺍⾻乛⻗虍卅ュ㐅⻞⼶㇝卌𠁼⺬𠆢尢⺌⺁𠃍𠃋龵⺥㇉𧰨𠄌朩𠤎镸⼢牜亅㇅癶𠂆⻊巜𠄎𠃑𱼀𠃜⾅覀䶹キヰ⺋⺝𠘨⼫⺕夊𰀪⺩𠂭𧾷⺀"

local function init(env)
    local config = env.engine.schema.config
    local code_rvdb = config:get_string('schema_name/code')
    env.code_rvdb = ReverseDb('build/' .. code_rvdb .. '.reverse.bin')
    env.mem = Memory(env.engine, Schema(code_rvdb))
    env.his_inp = config:get_string('history/input')
    env.delimiter = config:get_string('speller/delimiter')
    env.freqchr = config:get_string('yuhao_postpone_full_code/selected_chars')
    env.max_index = config:get_int('yuhao_postpone_full_code/lua/max_index')
        or 3
end

local function get_short(codestr)
    local s = ' ' .. codestr
    for code in s:gmatch('%l+') do
        if s:find(' ' .. code .. '%l+') then
            return code
        end
    end
end

local function has_short_and_is_full(cand, env)
    -- completion 和 sentence 类型不属于精确匹配，但要通过 cand:get_genuine() 判
    -- 断，因为 simplifier 会覆盖类型为 simplified。先行判断 type 并非必要，只是
    -- 为了轻微的性能优势。
    local cand_gen = cand:get_genuine()
    if cand_gen.type == 'completion' or cand_gen.type == 'sentence' then
        return false, true
    end
    local input = env.engine.context.input
    local cand_input = input:sub(cand.start + 1, cand._end)
    -- 去掉可能含有的 delimiter。
    cand_input = cand_input:gsub('[' .. env.delimiter .. ']', '')
    -- 字根可能设置了特殊扩展码，不视作全码，不予后置。
    if cand_input:len() > 2 and radstr:find(cand_gen.text, 1, true) then
        return
    end
    -- history_translator 不后置。
    if cand_input == env.his_inp then return end
    local codestr = env.code_rvdb:lookup(cand_gen.text)
    local is_first = true
    if env.mem:dict_lookup(string.sub(codestr, 1, 3), false, 1) then
        local count = 0
        for entry in env.mem:iter_dict() do
            count = count + 1
            if entry.text == cand_gen.text then
                break
            end
        end
        if count > 1 then
            is_first = false
        end
    end
    local not_full = not
        string.find(' ' .. codestr .. ' ', ' ' .. cand_input .. ' ', 1, true)
    local short = not not_full and get_short(codestr)
    -- 注意排除有简码但是输入的是不规则编码的情况

    if (env.freqchr == "") or (env.freqchr == nil) then
        return short and is_first and cand_input:find('^' .. short .. '%l+'),
            not_full
    else
        -- 只後置選定的漢字
        return short and is_first and cand_input:find('^' .. short .. '%l+') and env.freqchr:find(cand_gen.text, 1, true),
            not_full
    end
end

local function filter(input, env)
    local context = env.engine.context
    if not context:get_option("yuhao_postpone_full_code") then
        for cand in input:iter() do yield(cand) end
    else
        -- 具体实现不是后置目标候选，而是前置非目标候选
        local dropped_cands = {}
        local done_drop
        local pos = 1
        -- Todo: 计算 pos 时考虑可能存在的重复候选被 uniquifier 合并的情况。
        for cand in input:iter() do
            if done_drop then
                yield(cand)
            else
                -- 后置不越过 env.max_index 和以下几类候选：
                -- 1) 顶功方案使用 script_translator 导致的匹配部分输入的候选，例如输入
                -- otu 且光标在 u 后时会出现编码为 ot 的候选。不过通过填满码表的三码和
                -- 四码的位置，能消除这类候选。2) 顶功方案的造词翻译器允许出现的
                -- completion 类型候选。3) 顶功方案的补空候选——全角空格（ U+3000）。
                local is_bad_script_cand = cand._end < context.caret_pos
                local drop, not_full = has_short_and_is_full(cand, env)
                if pos >= env.max_index
                    or is_bad_script_cand or not_full or cand.text == '　' then
                    for i, cand in ipairs(dropped_cands) do yield(cand) end
                    done_drop = true
                    yield(cand)
                    -- 精确匹配的词组不予后置
                elseif not drop or utf8.len(cand.text) > 1 then
                    yield(cand)
                    pos = pos + 1
                else
                    table.insert(dropped_cands, cand)
                end
            end
        end
        for i, cand in ipairs(dropped_cands) do yield(cand) end
    end
end

return { init = init, func = filter }
