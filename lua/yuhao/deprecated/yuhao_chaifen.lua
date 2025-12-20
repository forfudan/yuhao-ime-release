--[[
原作者：ace-who
https://github.com/Ace-Who/rime-xuma/blob/master/schema/lua/ace/xuma_spelling.lua
用于生成词语拆分
------------------------------------------------------------------------

修改者: 朱宇浩 (forFudan) <dr.yuhao.zhu@outlook.com>
更新:
- 20240919: 將詞語拆分中的菱形改爲全角波浪號.
- 20240921: 更改默認的注解等級.
- 20250210: 修正了一些顯示錯誤.
- 20250514: 增加參數,可以選擇是否爲詞語顯示提示.
- 20250718: 允許用戶在陸標拆分和臺標拆分之間進行切換.
- 20251213: 修正變體選擇器導致的文本長度錯誤判斷問題.
---------------------------------------------------------------------------
]]

--[[
    Map a function over a table and return a new table with the results.
    @param table The table to map over
    @param func The function to apply to each value
    @return A new table with the mapped values
]]
function map(table, func)
  local t = {}
  for k, v in pairs(table) do
    t[k] = func(v)
  end
  return t
end

--[[
    Split a UTF-8 string into an array of individual characters.
    @param str The UTF-8 string to split
    @return Array of individual UTF-8 characters
]]
function utf8chars(str)
  local chars = {}
  for pos, code in utf8.codes(str) do
    chars[#chars + 1] = utf8.char(code)
  end
  return chars
end

-- rime.lua

local rime = {}
package.loaded[...] = rime
rime.encoder = {}

--[[
    Parse a formula string into a rule table for character encoding.
    @param formula A string containing uppercase and lowercase letter pairs
    @return Table of rules with character and code indices, or nil if invalid formula
]]
function rime.encoder.parse_formula(formula)
  if type(formula) ~= 'string' or formula:gsub('%u%l', '') ~= '' then return end
  local rule = {}
  local A, a, U, u, Z, z = ('AaUuZz'):byte(1, -1)
  for m in formula:gmatch('%u%l') do
    local upper, lower = m:byte(1, 2)
    local char_idx = upper < U and upper - A + 1 or upper - Z - 1
    local code_idx = lower < u and lower - a + 1 or lower - z - 1
    rule[#rule + 1] = { char_idx, code_idx }
  end
  return rule
end

--[[
    Load encoding settings and generate corresponding rules.
    @param setting Table of encoding settings with length_equal or length_in_range
    @return Table of rules indexed by length
]]
function rime.encoder.load_settings(setting)
  -- 注意到公式同则规则同，可通过 f2r 在 rt 中作引用定义，以节省资源。
  local ft, f2r, rt = {}, {}, {}
  for _, t in ipairs(setting) do
    if t.length_equal then
      ft[t.length_equal] = t.formula
    elseif t.length_in_range then
      local min, max = table.unpack(t.length_in_range)
      for l = min, max do
        ft[l] = t.formula
      end
    end
  end
  -- setting 中的 length 不一定连续且一般不包括 1，所以不能用 ipairs()。
  for k, f in pairs(ft) do
    local rule = rime.encoder.parse_formula(f)
    if not rule then return end
    if not f2r[f] then f2r[f] = rule end
    rt[k] = f2r[f]
  end
  return rt
end

--[[
    Toggle an option in the context.
    @param name The name of the option to toggle
    @param context The context in which to toggle the option
]]
function rime.switch_option(name, context)
  context:set_option(name, not context:get_option(name))
end

--[[
    Cycle options of a switcher. When #options == 1, toggle the only option.
    Otherwise unset the first set option and unset the next, or the previous if
    'reverse' is true. When no set option is present, try the key
    'options.save', then 'options.default', then 1.
    @param options Table of options to cycle through
    @param env The environment containing the context
    @param reverse Boolean indicating whether to cycle in reverse
    @return The index of the selected option
]]
function rime.cycle_options(options, env, reverse)
  local context = env.engine.context
  if #options == 0 then return 0 end
  if #options == 1 then
    rime.switch_option(options[1], context)
    return 1
  end
  local state
  for k, v in ipairs(options) do
    if context:get_option(v) then
      context:set_option(v, false)
      state = (reverse and (k - 1) or (k + 1)) % #options
      if state == 0 then state = #options end
      break
    end
  end
  local k = state or options.save or options.default or 1
  context:set_option(options[k], true)
  return k
end

--[[
    Set an option in 'options' if no one is set yet.
    @param options Table of options to set
    @param context The context in which to set the option
]]
function rime.init_options(options, context)
  for k, v in ipairs(options) do
    if context:get_option(v) then return end
  end
  local k = state or options.save or options.default or 1
  context:set_option(options[k], true)
end

--[[
    Generate a processor that cycles a group of options with a key.
    For now only works when composing.
    @param options Table of options to cycle through
    @param cycle_key_config_path Path to the cycle key configuration
    @param switch_key_config_path Path to the switch key configuration
    @param reverse Boolean indicating whether to cycle in reverse
    @return The processor object
]]
function rime.make_option_cycler(
    options,
    cycle_key_config_path,
    switch_key_config_path,
    reverse
)
  local processor, cycle_key, switch_key = {}
  processor.init = function(env)
    local config = env.engine.schema.config
    cycle_key = config:get_string(cycle_key_config_path)
    switch_key = config:get_string(switch_key_config_path)
  end
  processor.func = function(key, env)
    local context = env.engine.context
    if context:is_composing() and key:repr() == cycle_key then
      local state = rime.cycle_options(options, env, reverse)
      if state > 1 then options.save = state end
      return 1
    elseif context:is_composing() and key:repr() == switch_key then
      -- 选项状态可能在切换方案时被重置，因此需检测更新。但是不能在 filter.init
      -- 中检测，因为得到的似乎是重置之前的状态，说明组件初始化先于状态重置。为
      -- 经济计，仅在手动切换开关时检测。
      -- https://github.com/rime/librime/issues/449
      -- Todo: 对于较新的 librime-lua，尝试利用 option_update_notifier 更新
      -- options.save
      for k, v in ipairs(options) do
        if context:get_option(v) then
          if k > 1 then options.save = k end
        end
      end
      local k = options.save or options.default
      -- Consider the 1st options as OFF state.
      if context:get_option(options[1]) then
        context:set_option(options[1], false)
        context:set_option(options[k], true)
      else
        context:set_option(options[k], false)
        context:set_option(options[1], true)
      end
      return 1
    end
    return 2 -- kNoop
  end
  return processor
end

-- start of yuhao_chaifen.lua

local config = {}
config.encode_rules = {
  { length_equal = 2,            formula = 'AaAbBaBb' },
  { length_equal = 3,            formula = 'AaBaCaCb' },
  { length_in_range = { 4, 10 }, formula = 'AaBaCaZa' }
}
-- 注意借用编码规则有局限性：取码索引不一定对应取根索引，尤其是从末尾倒数时。
local spelling_rules = rime.encoder.load_settings(config.encode_rules)
-- options 要与方案保持一致
local options = {
  'yuhao_chaifen.off',
  'yuhao_chaifen.lv1',
  'yuhao_chaifen.lv2',
  'yuhao_chaifen.lv3'
}
options.default = 4

local processor = rime.make_option_cycler(options,
  'yuhao_chaifen/lua/cycle_key',
  'yuhao_chaifen/lua/switch_key')

--[[
    Transform the input string format.
    @param s The input string
    @return The transformed string
]]
local function xform(s)
  -- input format: "[spelling,code_code...,pinyin_pinyin...]"
  -- output format: "〔 spelling · code code ... · pinyin pinyin ... 〕"
  return s == '' and s or s:gsub('%[', '〔')
      :gsub('%]', '〕')
      :gsub('{', '<')
      :gsub('}', '>')
      :gsub('_', ' ')
      :gsub(',', ' · ')
      :gsub(' ·  ·  · ', ' · ')
      :gsub(' ·  · ', ' · ')
      :gsub(' ·  · ', ' · ')
      :gsub('〔 · 〕', '')
      :gsub('〔〕', '')
      :gsub('〔 · ', "〔")
end

--[[
    Parse the spelling string into radicals.
    @param str The spelling string
    @return Table of radicals
]]
local function parse_spll(str)
  -- Handle spellings like "{于下}{四点}丶"(for 求) where some radicals are
  -- represented by characters in braces.
  local radicals = {}
  for seg in str:gsub('%b{}', ' %0 '):gmatch('%S+') do
    if seg:find('^{.+}$') then
      table.insert(radicals, seg)
    else
      for pos, code in utf8.codes(seg) do
        table.insert(radicals, utf8.char(code))
      end
    end
  end
  return radicals
end

--[[
    Parse the raw tricomment string.
    @param str The raw tricomment string
    @return The parsed tricomment string
]]
local function parse_raw_tricomment(str)
  return str:gsub(',.*', ''):gsub('^%[', '')
end

--[[
    Parse the raw code comment string.
    Edited by Yuhao Zhu.
    @param str The raw code comment string
    @return The parsed code comment string
]]
local function parse_raw_code_comment(str)
  return str:gsub('%[.-,(.-),.*%]', '[%1]'):gsub(',.*', ''):gsub('^%[', '')
end

--[[
    Generate the spelling for a phrase.
    @param s The phrase string
    @param spll_rvdb The spelling reverse database
    @return The generated spelling string
]]
local function spell_phrase(s, spll_rvdb)
  local chars = utf8chars(s)
  local rule = spelling_rules[#chars]
  if not rule then return end
  local radicals = {}
  for i, coord in ipairs(rule) do
    local char_idx = coord[1] > 0 and coord[1] or #chars + 1 + coord[1]
    local raw = spll_rvdb:lookup(chars[char_idx])
    -- 若任一取码单字没有注解数据，则不对词组作注。
    if raw == '' then return end
    local char_radicals = parse_spll(parse_raw_tricomment(raw))
    local code_idx = coord[2] > 0 and coord[2] or #char_radicals + 1 + coord[2]
    radicals[i] = char_radicals[code_idx] or '～'
  end
  return table.concat(radicals)
end

--[[
    Generate the code for a phrase.
    Edited by Yuhao Zhu.
    @param s The phrase string
    @param spll_rvdb The spelling reverse database
    @return The generated code string
]]
local function code_phrase(s, spll_rvdb)
  local chars = utf8chars(s)
  local rule = spelling_rules[#chars]
  if not rule then return end
  local radicals = {}
  for i, coord in ipairs(rule) do
    local char_idx = coord[1] > 0 and coord[1] or #chars + 1 + coord[1]
    local raw = spll_rvdb:lookup(chars[char_idx])
    -- 若任一取码单字没有注解数据，则不对词组作注。
    if raw == '' then return end
    local char_radicals = parse_spll(parse_raw_code_comment(raw))
    local code_idx = coord[2] > 0 and coord[2] or #char_radicals + 1 + coord[2]
    radicals[i] = char_radicals[code_idx] or '～'
  end
  return table.concat(radicals)
end

--[[
    檢查文本是否爲單個漢字
    @param text 要檢查的文本
    @return Boolean 表示是否爲單個漢字(可能帶有變體選擇器 0xE0100 - 0xE01EF)
]]
local function is_single_char(text)
  local text_len = utf8.len(text)
  if text_len == 1 then
    return true
  elseif text_len == 2 then
    -- Check if the second character is a Variation Selector (U+E0100 - U+E01EF)
    local chars = utf8chars(text)
    if chars[2] then
      local codepoint = utf8.codepoint(chars[2])
      return codepoint >= 0xE0100 and codepoint <= 0xE01EF
    end
  end
  return false
end

--[[
    Get the tricomment for a candidate.
    Edited by Yuhao Zhu.
    @param cand The candidate object
    @param env The environment containing the reverse database
    @return The tricomment string
]]
local function get_tricomment(cand, env, spll_rvdb)
  local text = cand.text
  if is_single_char(text) then
    local raw_spelling = spll_rvdb:lookup(text)
    if raw_spelling == '' then return end
    return env.engine.context:get_option('yuhao_chaifen.lv1')
        and xform(raw_spelling:gsub('%[(.-),.*%]', '[%1]'))
        or env.engine.context:get_option('yuhao_chaifen.lv2')
        and xform(raw_spelling:gsub('%[(.-,.-),.*%]', '[%1]'))
        or xform(raw_spelling) -- yuhao_chaifen.lv3 is on
  elseif env.phrase == 0 then
    return ""
  elseif utf8.len(text) > 1 then
    local spelling = spell_phrase(text, spll_rvdb)
    if not spelling then return end
    spelling = spelling:gsub('{(.-)}', '<%1>')
    if env.engine.context:get_option('yuhao_chaifen.lv1') then
      return ('〔%s〕'):format(spelling)
    end
    local code = code_phrase(text, spll_rvdb)
    if code ~= '' then
      local codes = {}
      for m in code:gmatch('%S+') do codes[#codes + 1] = m end
      table.sort(codes, function(i, j) return i:len() < j:len() end)
      return ('〔%s · %s〕'):format(spelling, table.concat(codes, ' '))
    else
      return ('〈 %s 〉'):format(spelling)
    end
  end
end

--[[
    Define the filter function.
    @param input The input object
    @param env The environment containing the context and reverse database
]]
local function filter(input, env)
  if env.engine.context:get_option('yuhao_chaifen.off') then
    for cand in input:iter() do yield(cand) end
    return
  end
  local spll_rvdb = nil
  local code_rvdb = nil
  if env.engine.context:get_option('yuhao_chaifen_source') then
    spll_rvdb = env.spll_rvdb_tw
    code_rvdb = env.code_rvdb_tw
  else
    spll_rvdb = env.spll_rvdb
    code_rvdb = env.code_rvdb
  end
  for cand in input:iter() do
    if cand.type == 'simplified' then
      local comment = (get_tricomment(cand, env, spll_rvdb) or '') .. cand.comment
      cand = Candidate("simp_rvlk", cand.start, cand._end, cand.text, comment)
    else
      local add_comment = cand.type == 'punct'
          and code_rvdb:lookup(cand.text)
          or cand.type ~= 'sentence'
          and get_tricomment(cand, env, spll_rvdb)
      if add_comment and add_comment ~= '' then
        cand.comment = cand.type ~= 'completion'
            and env.is_mixtyping
            and add_comment
            or add_comment .. cand.comment
      end
    end
    yield(cand)
  end
end

--[[
    Initialize the environment.
    @param env The environment to initialize
]]
local function init(env)
  local spll_rvdb = env.engine.schema.config:get_string('schema_name/spelling')
  local code_rvdb = env.engine.schema.config:get_string('schema_name/code')
  local spll_rvdb_tw = env.engine.schema.config:get_string('schema_name/spelling_tw')
  local code_rvdb_tw = env.engine.schema.config:get_string('schema_name/code_tw')
  local abc_extags_size = env.engine.schema.config:get_list_size('abc_segmentor/extra_tags')
  env.spll_rvdb = ReverseDb('build/' .. spll_rvdb .. '.reverse.bin')
  env.code_rvdb = ReverseDb('build/' .. code_rvdb .. '.reverse.bin')
  env.spll_rvdb_tw = ReverseDb('build/' .. spll_rvdb_tw .. '.reverse.bin') or env.spll_rvdb
  env.code_rvdb_tw = ReverseDb('build/' .. code_rvdb_tw .. '.reverse.bin') or env.code_rvdb
  env.is_mixtyping = abc_extags_size > 0
  rime.init_options(options, env.engine.context)
  env.phrase = env.engine.schema.config:get_int('yuhao_chaifen/lua/phrase') or 1
end

-- Return the filter and processor
return { filter = { init = init, func = filter }, processor = processor }
