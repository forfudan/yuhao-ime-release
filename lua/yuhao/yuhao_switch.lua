--[[
-- 作者：王牌餅乾
-- https://github.com/lost-melody/
-- 转载请保留作者名
-- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International


版本：
20240810, 王牌餅乾:
    初始版本.
20251222, 朱宇浩:
    增加 menu 宏類型, 支持多行顯示多個開關項.
    添加 selector 宏類型, 支持直接選擇特定選項.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--]]

local yuhao_switch_proc = {} -- 開關管理-processor
local yuhao_switch_tr   = {} -- 開關管理-translator

-- ######## DEFINITION ########

local kRejected = 0 -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted = 1 -- 收: 由rime響應該按鍵
local kNoop     = 2 -- 無: 請下一個processor繼續看

-- 宏類型枚舉
local macro_types = {
    tip      = "tip",
    switch   = "switch",
    radio    = "radio",
    selector = "selector",
    menu     = "menu",
    shell    = "shell",
    eval     = "eval",
}

-- 候選序號標記
local index_indicators = {"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰"}

-- ######## TOOLS ########

-- 返回被選中的候選的索引, 來自 librime-lua/sample 示例
local function select_index(key, env)
    local ch = key.keycode
    local index = -1
    local select_keys = env.engine.schema.select_keys
    if select_keys ~= nil and select_keys ~= "" and not key.ctrl() and ch >= 0x20 and ch < 0x7f then
        local pos = string.find(select_keys, string.char(ch))
        if pos ~= nil then index = pos end
    elseif ch >= 0x30 and ch <= 0x39 then
        index = (ch - 0x30 + 9) % 10
    elseif ch >= 0xffb0 and ch < 0xffb9 then
        index = (ch - 0xffb0 + 9) % 10
    elseif ch == 0x20 then
        index = 0
    end
    return index
end

-- 設置開關狀態, 並更新保存的配置值
local function set_option(env, ctx, option_name, value)
    ctx:set_option(option_name, value)
    if env.switcher then
        -- 在支持的情況下, 更新保存的開關狀態
        local swt = env.switcher
        if swt:is_auto_save(option_name) and swt.user_config ~= nil then
            swt.user_config:set_bool("var/option/" .. option_name, value)
        end
    end
end

local _unix_supported
-- 是否支持 Unix 命令
local function unix_supported()
    if _unix_supported == nil then
        local res
        _unix_supported, res = pcall(io.popen, "sleep 0")
        if _unix_supported and res then
            res:close()
        end
    end
    return _unix_supported
end

-- 下文的 new_tip, new_switch, new_radio 等是目前已實現的宏類型
-- 其返回類型統一定義爲:
-- {
--   type = "string",
--   name = "string",
--   display = function(self, ctx) ... end -> string
--   trigger = function(self, ctx) ... end
-- }
-- 其中:
-- type 字段僅起到標識作用
-- name 字段亦非必須
-- display() 爲該宏在候選欄中顯示的效果, 通常 name 非空時直接返回 name 的值
-- trigger() 爲該宏被選中時, 上屏的文本内容, 返回空卽不上屏

---提示語或快捷短語
---顯示爲 name, 上屏爲 text
---@param name string
local function new_tip(name, text)
    local tip = {
        type = macro_types.tip,
        name = name,
        text = text,
    }
    function tip:display(ctx)
        return #self.name ~= 0 and self.name or ""
    end

    function tip:trigger(env, ctx)
        if #text ~= 0 then
            env.engine:commit_text(text)
        end
        ctx:clear()
    end

    return tip
end

---開關
---顯示 name 開關當前的狀態, 並在選中切換狀態
---states 分别指定開關狀態爲 開 和 關 時的顯示效果
---@param name string
---@param states table
local function new_switch(name, states)
    local switch = {
        type = macro_types.switch,
        name = name,
        states = states,
    }
    function switch:display(ctx)
        local current_value = ctx:get_option(self.name)
        local result = {}
        for i, state in ipairs(self.states) do
            if (i == 2 and current_value) or (i == 1 and not current_value) then
                table.insert(result, "▸" .. state)
            else
                table.insert(result, state)
            end
        end
        return table.concat(result, " · ")
    end

    function switch:trigger(env, ctx)
        local current_value = ctx:get_option(self.name)
        if current_value ~= nil then
            set_option(env, ctx, self.name, not current_value)
        end
    end

    return switch
end

---單選
---顯示一組 names 開關當前的狀態, 並在選中切換關閉當前開啓項, 並打開下一項
---states 指定各組開關的 name 和當前開啓的開關時的顯示效果
---@param states table
local function new_radio(states)
    local radio = {
        type   = macro_types.radio,
        states = states,
    }
    function radio:display(ctx)
        local result = {}
        for _, op in ipairs(self.states) do
            local value = ctx:get_option(op.name)
            if value then
                table.insert(result, "▸" .. op.display)
            else
                table.insert(result, op.display)
            end
        end
        return table.concat(result, " · ")
    end

    function radio:trigger(env, ctx)
        for i, op in ipairs(self.states) do
            local value = ctx:get_option(op.name)
            if value then
                -- 關閉當前選項, 開啓下一選項
                set_option(env, ctx, op.name, not value)
                set_option(env, ctx, self.states[i % #self.states + 1].name, value)
                return
            end
        end
        -- 全都没開, 那就開一下第一個吧
        set_option(env, ctx, self.states[1].name, true)
    end

    return radio
end

---選擇器
---直接選擇特定選項，而不是循環切換
---顯示所有選項及序號
---@param states table
---@param numbering table 自定義的數字標注（可選）
local function new_selector(states, numbering)
    local selector = {
        type      = macro_types.selector,
        states    = states,
        numbering = numbering or {},
    }
    
    function selector:display(ctx)
        local state_displays = {}
        -- 顯示所有選項
        for i, op in ipairs(self.states) do
            local value = ctx:get_option(op.name)
            local prefix = value and "▸" or ""
            -- 使用自定義數字或默認數字
            local num = self.numbering[i] or i
            local num_indicator = index_indicators[num] or tostring(num)
            table.insert(state_displays, prefix .. op.display .. num_indicator)
        end
        return table.concat(state_displays, " · ")
    end

    function selector:trigger(env, ctx, pressed_digit)
        if pressed_digit ~= nil then
            -- 根據按下的數字找到對應的選項索引
            local target_index = nil
            for i, num in ipairs(self.numbering) do
                if num == pressed_digit then
                    target_index = i
                    break
                end
            end
            
            -- 如果沒有自定義 numbering，使用默認映射
            if #self.numbering == 0 then
                target_index = pressed_digit
            end
            
            -- 關閉所有選項
            for _, op in ipairs(self.states) do
                set_option(env, ctx, op.name, false)
            end
            
            -- 開啟對應選項
            if target_index and target_index >= 1 and target_index <= #self.states then
                set_option(env, ctx, self.states[target_index].name, true)
            end
        end
    end

    return selector
end

---菜單
---顯示多個開關項，每個項佔一行，可通過數字鍵切換
---items 是一個數組，每個元素包含 type（switch/radio/selector）和對應的配置
---@param items table
local function new_menu(items)
    local menu = {
        type = macro_types.menu,
        items = items,
    }
    
    function menu:display(ctx)
        -- menu 類型不需要 display，因為會生成多個候選
        return ""
    end
    
    function menu:trigger(env, ctx, index)
        -- 觸發指定索引的項
        if index >= 1 and index <= #self.items then
            self.items[index]:trigger(env, ctx)
        end
    end
    
    return menu
end

---Shell 命令, 僅支持 Linux/Mac 系統, 其他平臺可通過下文提供的 eval 宏自行擴展
---name 非空時顯示其值, 爲空则顯示實時的 cmd 執行結果
---cmd 爲待執行的命令内容
---text 爲 true 時, 命令執行結果上屏, 否则僅執行
---@param name string
---@param cmd string
---@param text boolean
local function new_shell(name, cmd, text)
    if not unix_supported() then
        return nil
    end

    local template = "__macrowrapper() { %s ; }; __macrowrapper %s <<<''"
    local function get_fd(args)
        local cmdargs = {}
        for _, arg in ipairs(args) do
            table.insert(cmdargs, '"' .. arg .. '"')
        end
        return io.popen(string.format(template, cmd, table.concat(cmdargs, " ")), 'r')
    end

    local shell = {
        type = macro_types.tip,
        name = name,
        text = text,
    }

    function shell:display(ctx, args)
        return #self.name ~= 0 and self.name or self.text and get_fd(args):read('a')
    end

    function shell:trigger(env, ctx, args)
        local fd = get_fd(args)
        if self.text then
            local t = fd:read('a')
            fd:close()
            if #t ~= 0 then
                env.engine:commit_text(t)
            end
        end
        ctx:clear()
    end

    return shell
end

---Evaluate 宏, 執行給定的 lua 表達式
---name 非空時顯示其值, 否则顯示實時調用結果
---expr 必須 return 一個值, 其類型可以是 string, function 或 table
---返回 function 時, 該 function 接受一個 table 參數, 返回 string
---返回 table 時, 該 table 成員方法 peek 和 eval 接受 self 和 table 參數, 返回 string, 分别指定顯示效果和上屏文本
---@param name string
---@param expr string
local function new_eval(name, expr)
    local f = load(expr)
    if not f then
        return nil
    end

    local eval = {
        type = macro_types.eval,
        name = name,
        expr = f,
    }

    function eval:get_text(args, getter)
        if type(self.expr) == "function" then
            local res = self.expr(args)
            if type(res) == "string" then
                return res
            elseif type(res) == "function" or type(res) == "table" then
                self.expr = res
            else
                return ""
            end
        end

        local res
        if type(self.expr) == "function" then
            res = self.expr(args)
        elseif type(self.expr) == "table" then
            local get_text = self.expr[getter]
            res = type(get_text) == "function" and get_text(self.expr, args) or nil
        end
        return type(res) == "string" and res or ""
    end

    function eval:display(ctx, args)
        if #self.name ~= 0 then
            return self.name
        else
            local _, res = pcall(self.get_text, self, args, "peek")
            return res
        end
    end

    function eval:trigger(env, ctx, args)
        local ok, res = pcall(self.get_text, self, args, "eval")
        if ok and #res ~= 0 then
            env.engine:commit_text(res)
        end
        ctx:clear()
    end

    return eval
end

---@param input string
---@param keylist table
local function get_macro_args(input, keylist)
    local sepset = ""
    for key in pairs(keylist) do
        -- only ascii keys
        sepset = key >= 0x20 and key <= 0x7f and sepset .. string.char(key) or sepset
    end
    -- matches "[^/]"
    local pattern = "[^" .. (#sepset ~= 0 and sepset or " ") .. "]*"
    local args = {}
    -- "echo/hello/world" -> "/hello", "/world"
    for str in string.gmatch(input, "/" .. pattern) do
        table.insert(args, string.sub(str, 2))
    end
    -- "echo/hello/world" -> "echo"
    return string.match(input, pattern) or "", args
end

-- 從方案配置中讀取宏配置
local function parse_conf_macro_list(env)
    local macros = {}
    local macro_map = env.engine.schema.config:get_map(env.name_space .. "/macros")
    -- macros:
    for _, key in ipairs(macro_map and macro_map:keys() or {}) do
        local cands = {}
        local cand_list = macro_map:get(key):get_list() or { size = 0 }
        -- macros/help:
        for i = 0, cand_list.size - 1 do
            local key_map = cand_list:get_at(i):get_map()
            -- macros/help[1]/type:
            local type = key_map and key_map:has_key("type") and key_map:get_value("type"):get_string() or ""
            if type == macro_types.tip then
                -- {type: tip, name: foo}
                if key_map:has_key("name") or key_map:has_key("text") then
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local text = key_map:has_key("text") and key_map:get_value("text"):get_string() or ""
                    table.insert(cands, new_tip(name, text))
                end
            elseif type == macro_types.switch then
                -- {type: switch, name: single_char, states: []}
                if key_map:has_key("name") and key_map:has_key("states") then
                    local name = key_map:get_value("name"):get_string()
                    local states = {}
                    local state_list = key_map:get("states"):get_list() or { size = 0 }
                    for idx = 0, state_list.size - 1 do
                        table.insert(states, state_list:get_value_at(idx):get_string())
                    end
                    if #name ~= 0 and #states > 1 then
                        table.insert(cands, new_switch(name, states))
                    end
                end
            elseif type == macro_types.radio then
                -- {type: radio, names: [], states: []}
                if key_map:has_key("names") and key_map:has_key("states") then
                    local names, states = {}, {}
                    local name_list = key_map:get("names"):get_list() or { size = 0 }
                    for idx = 0, name_list.size - 1 do
                        table.insert(names, name_list:get_value_at(idx):get_string())
                    end
                    local state_list = key_map:get("states"):get_list() or { size = 0 }
                    for idx = 0, state_list.size - 1 do
                        table.insert(states, state_list:get_value_at(idx):get_string())
                    end
                    if #names > 1 and #names == #states then
                        local radio = {}
                        for idx, name in ipairs(names) do
                            if #name ~= 0 and #states[idx] ~= 0 then
                                table.insert(radio, { name = name, display = states[idx] })
                            end
                        end
                        table.insert(cands, new_radio(radio))
                    end
                end
            elseif type == macro_types.selector then
                -- {type: selector, names: [], states: [], numbering: []}
                if key_map:has_key("names") and key_map:has_key("states") then
                    local names, states, numbering = {}, {}, {}
                    local name_list = key_map:get("names"):get_list() or { size = 0 }
                    for idx = 0, name_list.size - 1 do
                        table.insert(names, name_list:get_value_at(idx):get_string())
                    end
                    local state_list = key_map:get("states"):get_list() or { size = 0 }
                    for idx = 0, state_list.size - 1 do
                        table.insert(states, state_list:get_value_at(idx):get_string())
                    end
                    -- 讀取自定義數字標注（可選）
                    if key_map:has_key("numbering") then
                        local numbering_list = key_map:get("numbering"):get_list() or { size = 0 }
                        for idx = 0, numbering_list.size - 1 do
                            table.insert(numbering, numbering_list:get_value_at(idx):get_int())
                        end
                    end
                    if #names > 0 and #names == #states then
                        local selector = {}
                        for idx, name in ipairs(names) do
                            if #name ~= 0 and #states[idx] ~= 0 then
                                table.insert(selector, { name = name, display = states[idx] })
                            end
                        end
                        table.insert(cands, new_selector(selector, numbering))
                    end
                end
            elseif type == macro_types.menu then
                -- {type: menu, items: [{type: switch/radio, ...}, ...]}
                if key_map:has_key("items") then
                    local items = {}
                    local item_list = key_map:get("items"):get_list() or { size = 0 }
                    for idx = 0, item_list.size - 1 do
                        local item_map = item_list:get_at(idx):get_map()
                        local item_type = item_map and item_map:has_key("type") and item_map:get_value("type"):get_string() or ""
                        
                        if item_type == macro_types.switch then
                            -- switch item
                            if item_map:has_key("name") and item_map:has_key("states") then
                                local name = item_map:get_value("name"):get_string()
                                local states = {}
                                local state_list = item_map:get("states"):get_list() or { size = 0 }
                                for s_idx = 0, state_list.size - 1 do
                                    table.insert(states, state_list:get_value_at(s_idx):get_string())
                                end
                                if #name ~= 0 and #states > 1 then
                                    table.insert(items, new_switch(name, states))
                                end
                            end
                        elseif item_type == macro_types.radio then
                            -- radio item
                            if item_map:has_key("names") and item_map:has_key("states") then
                                local names, states = {}, {}
                                local name_list = item_map:get("names"):get_list() or { size = 0 }
                                for n_idx = 0, name_list.size - 1 do
                                    table.insert(names, name_list:get_value_at(n_idx):get_string())
                                end
                                local state_list = item_map:get("states"):get_list() or { size = 0 }
                                for s_idx = 0, state_list.size - 1 do
                                    table.insert(states, state_list:get_value_at(s_idx):get_string())
                                end
                                if #names > 1 and #names == #states then
                                    local radio = {}
                                    for r_idx, name in ipairs(names) do
                                        if #name ~= 0 and #states[r_idx] ~= 0 then
                                            table.insert(radio, { name = name, display = states[r_idx] })
                                        end
                                    end
                                    table.insert(items, new_radio(radio))
                                end
                            end
                        elseif item_type == macro_types.selector then
                            -- selector item
                            if item_map:has_key("names") and item_map:has_key("states") then
                                local names, states, numbering = {}, {}, {}
                                local name_list = item_map:get("names"):get_list() or { size = 0 }
                                for n_idx = 0, name_list.size - 1 do
                                    table.insert(names, name_list:get_value_at(n_idx):get_string())
                                end
                                local state_list = item_map:get("states"):get_list() or { size = 0 }
                                for s_idx = 0, state_list.size - 1 do
                                    table.insert(states, state_list:get_value_at(s_idx):get_string())
                                end
                                if item_map:has_key("numbering") then
                                    local numbering_list = item_map:get("numbering"):get_list() or { size = 0 }
                                    for num_idx = 0, numbering_list.size - 1 do
                                        table.insert(numbering, numbering_list:get_value_at(num_idx):get_int())
                                    end
                                end
                                if #names > 0 and #names == #states then
                                    local selector = {}
                                    for sel_idx, name in ipairs(names) do
                                        if #name ~= 0 and #states[sel_idx] ~= 0 then
                                            table.insert(selector, { name = name, display = states[sel_idx] })
                                        end
                                    end
                                    table.insert(items, new_selector(selector, numbering))
                                end
                            end
                        end
                    end
                    if #items > 0 then
                        table.insert(cands, new_menu(items))
                    end
                end
            elseif type == macro_types.shell then
                -- {type: shell, name: foo, cmd: "echo hello"}
                if key_map:has_key("cmd") and (key_map:has_key("name") or key_map:has_key("text")) then
                    local cmd = key_map:get_value("cmd"):get_string()
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local text = key_map:has_key("text") and key_map:get_value("text"):get_bool() or false
                    local hijack = key_map:has_key("hijack") and key_map:get_value("hijack"):get_bool() or false
                    if #cmd ~= 0 and (#name ~= 0 or text) then
                        table.insert(cands, new_shell(name, cmd, text))
                        cands.hijack = cands.hijack or hijack
                    end
                end
            elseif type == macro_types.eval then
                -- {type: eval, name: foo, expr: "os.date()"}
                if key_map:has_key("expr") then
                    local name = key_map:has_key("name") and key_map:get_value("name"):get_string() or ""
                    local expr = key_map:get_value("expr"):get_string()
                    local hijack = key_map:has_key("hijack") and key_map:get_value("hijack"):get_bool() or false
                    if #expr ~= 0 then
                        table.insert(cands, new_eval(name, expr))
                        cands.hijack = cands.hijack or hijack
                    end
                end
            end
        end
        if #cands ~= 0 then
            macros[key] = cands
        end
    end
    return macros
end

-- 從方案配置中讀取功能鍵配置
local function parse_conf_funckeys(env)
    local funckeys = {
        macro = {},
    }
    local keys_map = env.engine.schema.config:get_map(env.name_space .. "/funckeys")
    for _, key in ipairs(keys_map and keys_map:keys() or {}) do
        if funckeys[key] then
            local char_list = keys_map:get(key):get_list() or { size = 0 }
            for i = 0, char_list.size - 1 do
                funckeys[key][char_list:get_value_at(i):get_int() or 0] = true
            end
        end
    end
    return funckeys
end

-- 按命名空間歸類方案配置, 而不是按会話, 以减少内存佔用
local namespaces = {}
function namespaces:init(env)
    -- 每次都重新讀取配置項，以支持動態更新
    local config = {}
    config.macros = parse_conf_macro_list(env)
    config.funckeys = parse_conf_funckeys(env)
    namespaces:set_config(env, config)
end
function namespaces:set_config(env, config)
    namespaces[env.name_space] = namespaces[env.name_space] or {}
    namespaces[env.name_space].config = config
end
function namespaces:config(env)
    return namespaces[env.name_space] and namespaces[env.name_space].config
end

-- ######## PROCESSOR ########

local function proc_handle_macros(env, ctx, macro, args, idx, selected_index)
    if macro then
        if macro[idx] then
            -- 對於 selector 類型，傳遞 selected_index 以支持直接選擇
            if macro[idx].type == macro_types.selector and selected_index ~= nil then
                macro[idx]:trigger(env, ctx, selected_index)
            else
                macro[idx]:trigger(env, ctx, args)
            end
        end
        return kAccepted
    end
    return kNoop
end

function yuhao_switch_proc.init(env)
    if Switcher then
        env.switcher = Switcher(env.engine)
    end

    -- 讀取配置項
    local ok = pcall(namespaces.init, namespaces, env)
    if not ok then
        local config = {}
        config.macros = {}
        config.funckeys = {}
        namespaces:set_config(env, config)
    end
end

function yuhao_switch_proc.func(key_event, env)
    local ctx = env.engine.context
    if #ctx.input == 0 or key_event:release() or key_event:alt() then
        -- 當前無輸入, 或不是我關注的鍵按下事件, 棄之
        return kNoop
    end

    local ch = key_event.keycode
    local funckeys = namespaces:config(env).funckeys
    if funckeys.macro[string.byte(string.sub(ctx.input, 1, 1))] then
        -- 當前輸入串以 funckeys/macro 定義的鍵集合開頭
        local name, args = get_macro_args(string.sub(ctx.input, 2), namespaces:config(env).funckeys.macro)
        local macro = namespaces:config(env).macros[name]
        if macro then
            if macro.hijack and ch > 0x20 and ch < 0x7f then
                ctx:push_input(string.char(ch))
                return kAccepted
            else
                -- 檢查第一個宏是否為 menu 類型
                if macro[1] and macro[1].type == macro_types.menu then
                    -- menu 類型，按數字切換對應行的選項
                    local digit_pressed = nil
                    if (ch >= 0x30 and ch <= 0x39) then
                        digit_pressed = ch - 0x30  -- 0x30='0', 0x31='1', ..., 0x39='9'
                        -- 0 映射到 10，1-9 映射到 1-9
                        digit_pressed = (digit_pressed == 0) and 10 or digit_pressed
                    elseif (ch >= 0xffb0 and ch <= 0xffb9) then
                        digit_pressed = ch - 0xffb0  -- 小鍵盤數字
                        digit_pressed = (digit_pressed == 0) and 10 or digit_pressed
                    end
                    if digit_pressed ~= nil and digit_pressed >= 1 and digit_pressed <= #macro[1].items then
                        -- 觸發對應行的切換
                        macro[1]:trigger(env, ctx, digit_pressed)
                        return kAccepted
                    end
                -- 檢查第一個宏是否為 selector 類型
                elseif macro[1] and macro[1].type == macro_types.selector then
                    -- 如果是 selector，檢查是否按下數字鍵
                    local digit_pressed = nil
                    if (ch >= 0x30 and ch <= 0x39) then
                        digit_pressed = ch - 0x30  -- 0x30='0', 0x31='1', ..., 0x39='9'
                    elseif (ch >= 0xffb0 and ch <= 0xffb9) then
                        digit_pressed = ch - 0xffb0  -- 小鍵盤數字
                    end
                    if digit_pressed ~= nil then
                        -- 按下數字鍵，觸發 selector
                        return proc_handle_macros(env, ctx, macro, args, 1, digit_pressed)
                    end
                else
                    -- 非 menu/selector 類型，使用原有邏輯
                    local idx = select_index(key_event, env)
                    if idx >= 0 then
                        return proc_handle_macros(env, ctx, macro, args, idx + 1)
                    end
                end
            end
            return kNoop
        end
    end

    return kNoop
end

function yuhao_switch_proc.fini(env)
end

-- ######## TRANSLATOR ########

-- 處理宏
local function tr_handle_macros(env, ctx, seg, input)
    local name, args = get_macro_args(input, namespaces:config(env).funckeys.macro)
    local macro = namespaces:config(env).macros[name]
    if macro then
        -- 檢查是否為 menu 類型
        if macro[1] and macro[1].type == macro_types.menu then
            -- menu 類型，為每個項生成一個候選
            for i, item in ipairs(macro[1].items) do
                local display_text = item:display(ctx, args)
                -- 構建顯示文本，加上數字前綴
                local cand_text = "按" .. tostring(i) .. "切換: " .. display_text
                -- 使用空的 text 參數（第4個），將顯示文本放在 comment（第5個）
                local cand = Candidate("macro", seg.start, seg._end, cand_text, "")
                cand.quality = 1000 - i  -- 確保順序
                yield(cand)
            end
            return  -- 確保返回
        else
            -- 其他類型，生成單個候選
            local text_list = {}
            for i, m in ipairs(macro) do
                table.insert(text_list, m:display(ctx, args) .. index_indicators[i])
            end
            local cand = Candidate("macro", seg.start, seg._end, "", table.concat(text_list, " "))
            yield(cand)
        end
    end
end

function yuhao_switch_tr.init(env)
    -- 讀取配置項
    local ok = pcall(namespaces.init, namespaces, env)
    if not ok then
        local config = {}
        config.macros = {}
        config.funckeys = {}
        namespaces:set_config(env, config)
    end
end

function yuhao_switch_tr.func(input, seg, env)
    local ctx = env.engine.context
    local funckeys = namespaces:config(env).funckeys
    if funckeys.macro[string.byte(string.sub(ctx.input, 1, 1))] then
        tr_handle_macros(env, ctx, seg, string.sub(input, 2))
        return
    end
end

function yuhao_switch_tr.fini(env)
end

-- ######## RETURN ########

return {
    proc = yuhao_switch_proc, -- 開關管理-processor
    tr   = yuhao_switch_tr,   -- 開關管理-translator
}
