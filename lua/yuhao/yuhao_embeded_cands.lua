-- 作者：王牌餅乾
-- https://github.com/lost-melody/
-- 转载请保留作者名
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
---------------------------------------

-- 將要被返回的過濾器對象
local embeded_cands_filter = {}

--[[
# xxx.schema.yaml
switches:
  - name: embeded_cands
    states: [ 普通, 嵌入 ]
    reset: 1
engine:
  filters:
    - lua_filter@*yuhao.yuhao_embeded_cands@embeded_cands
embeded_cands:
  option_name: embeded_cands                         # 開關
  index_indicators: [ ¹, ², ³, ⁴, ⁵, ⁶, ⁷, ⁸, ⁹, ⁰ ] # 嵌入候選的序號顯示格式
  first_format: "[${候選}]${Code}${Comment}"         # 首選的渲染格式
  next_format: "${候選}${Seq}${Comment}"             # 非首選的渲染格式
  separator: " "                                     # 候選之間的分隔符
key_binder:
  bindings:
    - { when: always, accept: "Control+Shift+E", toggle: embeded_cands }
--]]

-- 候選序號標記
local index_indicators = {"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰"}

-- 首選/非首選格式定義
-- Seq: 候選序號; Code: 編碼; 候選: 候選文本; Comment: 候選提示
local first_format = "${候選}${Comment}${Seq}"
local next_format = "${候選}${Comment}${Seq}"
local separator = " "

-- 讀取 schema.yaml 開關設置:
local option_name = "embeded_cands"

-- 從方案配置中讀取字符串
local function parse_conf_str(env, path, default)
    local str = env.engine.schema.config:get_string(env.name_space.."/"..path)
    if not str and default and #default ~= 0 then
        str = default
    end
    return str
end

-- 從方案配置中讀取字符串列表
local function parse_conf_str_list(env, path, default)
    local list = {}
    local conf_list = env.engine.schema.config:get_list(env.name_space.."/"..path)
    if conf_list then
        for i = 0, conf_list.size-1 do
            table.insert(list, conf_list:get_value_at(i).value)
        end
    elseif default then
        list = default
    end
    return list
end

-- 構造開關變更回調函數
local function get_switch_handler(env, op_name)
    local option
    if not env.option then
        option = {}
        env.option = option
    else
        option = env.option
    end
    -- 返回通知回調, 當改變選項值時更新暫存的值
    return function(ctx, name)
        if name == op_name then
            option[name] = ctx:get_option(name)
            if option[name] == nil then
                -- 當選項不存在時默認爲啟用狀態
                option[name] = true
            end
        end
    end
end

local function compile_formatter(format)
    -- "${Stash}[${候選}${Seq}]${Code}${Comment}"
    -- => "%s[%s%s]%s%s"
    -- => {"${Stash}", "${...}", "${...}", ...}
    local pattern = "%$%{[^{}]+%}"
    local verbs = {}
    for s in string.gmatch(format, pattern) do
        table.insert(verbs, s)
    end

    local res = {
        format = string.gsub(format, pattern, "%%s"),
        verbs = verbs,
    }
    local meta = { __index = function() return "" end }

    -- {"${v1}", "${v2}", ...} + {v1: a1, v2: a2, ...} = {a1, a2, ...}
    -- string.format("%s[%s%s]%s%s", a1, a2, ...)
    function res:build(dict)
        setmetatable(dict, meta)
        local args = {}
        for _, pat in ipairs(self.verbs) do
            table.insert(args, dict[pat])
        end
        return string.format(self.format, table.unpack(args))
    end

    return res
end

-- 按命名空間歸類方案配置, 而不是按会話, 以减少内存佔用
local namespaces = {}
function namespaces:init(env)
    -- 讀取配置項
    if not namespaces:config(env) then
        local config = {}
        config.index_indicators = parse_conf_str_list(env, "index_indicators", index_indicators)
        config.first_format = parse_conf_str(env, "first_format", first_format)
        config.next_format = parse_conf_str(env, "next_format", next_format)
        config.separator = parse_conf_str(env, "separator", separator)
        config.option_name = parse_conf_str(env, "option_name")

        config.formatter = {}
        config.formatter.first = compile_formatter(config.first_format)
        config.formatter.next = compile_formatter(config.next_format)
        namespaces:set_config(env, config)
    end
end
function namespaces:set_config(env, config)
    namespaces[env.name_space] = namespaces[env.name_space] or {}
    namespaces[env.name_space].config = config
end
function namespaces:config(env)
    return namespaces[env.name_space] and namespaces[env.name_space].config
end

function embeded_cands_filter.init(env)
    -- 讀取配置項
    local ok = pcall(namespaces.init, namespaces, env)
    if not ok then
        local config = {}
        config.index_indicators = index_indicators
        config.first_format = first_format
        config.next_format = next_format
        config.separator = separator
        config.option_name = parse_conf_str(env, "option_name")

        config.formatter = {}
        config.formatter.first = compile_formatter(config.first_format)
        config.formatter.next = compile_formatter(config.next_format)
        namespaces:set_config(env, config)
    end

    local config = namespaces:config(env)
    -- 是否指定開關
    if config.option_name and #config.option_name ~= 0 then
        -- 構造回調函數
        local handler = get_switch_handler(env, config.option_name)
        -- 初始化爲選項實際值, 如果設置了 reset, 則會再次觸發 handler
        handler(env.engine.context, config.option_name)
        -- 注册通知回調
        env.engine.context.option_update_notifier:connect(handler)
    else
        -- 未指定開關, 默認啓用
        config.option_name = option_name
        env.option = {}
        env.option[config.option_name] = true
    end
end

-- 渲染提示, 因爲提示經常有可能爲空, 抽取爲函數更昜操作
local function render_comment(comment)
    if string.match(comment, "^[ ~]") then
        -- 丟棄以空格和"~"開頭的提示串, 這通常是補全提示
        comment = ""
    elseif string.len(comment) ~= 0 then
        -- 自定義提示串格式
        comment = comment:gsub("〔", ""):gsub("〕", ""):gsub(" · ", "·")
        comment = "["..comment.."]"
    end
    return comment
end

-- 渲染單個候選項
local function render_cand(env, seq, code, text, comment)
    local formatter
    if seq == 1 then
        formatter = namespaces:config(env).formatter.first
    else
        formatter = namespaces:config(env).formatter.next
    end
    -- 渲染提示串
    comment = render_comment(comment)
    local cand = formatter:build({
        ["${Seq}"] = namespaces:config(env).index_indicators[seq],
        ["${Code}"] = code,
        ["${候選}"] = text,
        ["${Comment}"] = comment,
    })
    return cand
end

-- 過濾器
function embeded_cands_filter.func(input, env)
    if not env.option[namespaces:config(env).option_name] then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    -- 要顯示的候選數量
    local page_size = env.engine.schema.page_size
    -- 暫存當前頁候選, 然后批次送出
    local page_cands, page_rendered = {}, {}
    -- 暫存索引, 首選和預編輯文本
    local index, first_cand, preedit = 0, nil, ""

    local function refresh_preedit()
        if first_cand then
            first_cand.preedit = table.concat(page_rendered, namespaces:config(env).separator)
            -- 將暫存的一頁候選批次送出
            for _, c in ipairs(page_cands) do
                yield(c)
            end
        end
        -- 清空暫存
        first_cand, preedit = nil, ""
        page_cands, page_rendered = {}, {}
    end

    local hash = {}
    -- 迭代器
    local iter, obj = input:iter()
    -- 迭代由翻譯器輸入的候選列表
    local next = iter(obj)
    while next do
        -- 去除重複項
        if not hash[next.text] then
            hash[next.text] = true

            -- 頁索引自增, 滿足 1 <= index <= page_size
            index = index + 1

            -- 當前遍歷候選項
            local cand = Candidate(next.type, next.start, next._end, next.text, next.comment)
            cand.quality = next.quality
            cand.preedit = next.preedit

            if not first_cand then
                -- 把首選捉出來
                first_cand = cand
            end

            -- 修改首選的預编輯文本, 這会作爲内嵌編碼顯示到輸入處
            preedit = render_cand(env, index, first_cand.preedit, cand.text, cand.comment)

            -- 存入候選
            table.insert(page_cands, cand)
            table.insert(page_rendered, preedit)
            -- 遍歷完一頁候選後, 刷新預編輯文本
            if index == page_size then
                refresh_preedit()
                -- 下一頁, index歸零
                index = 0
            end
        end

        -- 當前候選處理完畢, 查詢下一個
        next = iter(obj)
    end

    -- 如果當前暫存候選不足page_size但没有更多候選, 則需要刷新預編輯並送出
    refresh_preedit()
end

function embeded_cands_filter.fini(env)
    env.option = nil
end

return embeded_cands_filter
