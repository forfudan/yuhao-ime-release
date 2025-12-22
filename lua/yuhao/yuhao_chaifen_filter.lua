--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
yuhao_chaifen_filter.lua
宇浩拆分注解過濾器
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
版本: 20251222
作者: 朱宇浩 (forFudan) <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0
    International
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
介紹:
本過濾器為候選詞添加拆分注解，顯示漢字的拆分、編碼、拼音等信息。

數據格式說明（來自反查數據庫）：
若 chaifen_code_for_all_roots 為 true，數據有 7 欄：
呢	[口尸匕,DMTi,DoMsiTi,ne_ní_nǐ_nī,,CJK,5462]
- 第一欄：拆分（口尸匕）
- 第二欄：編碼（DMTi）
- 第三欄：字根全編碼（DoMsiTi）
- 第四欄：拼音（ne_ní_nǐ_nī）
- 第五欄：注釋（可為空）
- 第六欄：字符集（CJK）
- 第七欄：Unicode 碼位（5462）

若 chaifen_code_for_all_roots 為 false，數據有 6 欄：
呢	[口尸匕,DMTi,ne_ní_nǐ_nī,,CJK,5462]
- 第一欄：拆分（口尸匕）
- 第二欄：編碼（DMTi）
- 第三欄：拼音（ne_ní_nǐ_nī）
- 第四欄：注釋（可為空）
- 第五欄：字符集（CJK）
- 第六欄：Unicode 碼位（5462）

Description:
This filter adds character decomposition annotations to candidates,
showing the breakdown, encoding, pinyin, and other information.

顯示級別：
- off:   關閉拆分功能
- lv1:   一重注解 - 僅顯示拆分（僅單字）
         例：〔口尸匕 · 🈩〕
- lv2:   二重注解 - 顯示拆分 + 編碼
         單字例：〔口尸匕 · DMTi · 🈔〕
         詞語例：〔Fi · Rje · Hsa · NwPe〕
- lv2d:  二重詳解 - 顯示拆分 + 編碼 + 字根全編碼（僅單字同時顯示 code 和 code_all_roots）
         單字例：〔口尸匕 · DMTi · DoMsiTi 🈖〕
         詞語例：〔Fi · Rje · Hsa · NwPe〕
- lv3:   多重注解 - 顯示完整信息
         單字例：〔口尸匕 · DMTi · ne ní nǐ nī · CJK · 5462 · 🈕〕
         詞語例：〔Fi · Rje · Hsa · NwPe〕

詞語編碼顯示規則：
- 少於max_code_length個字：顯示所有字的編碼
- max_code_length個或更多字：顯示前N-1個字和最後1個字的編碼，中間用 ... 表示省略
  例（max_code_length=5）：〔Fi · Rje · Hsa · NwPe ... Dji〕
- 字與字之間用 · 分隔（省略號兩側不加 ·）
- 詞語編碼在 lv2、lv2d 和 lv3 級別顯示
- 詞語任何模式下都使用普通編碼（code），不使用字根全編碼

格式化規則：
- 使用 · 分隔不同類型的信息
- 拼音中的下劃線 _ 轉換為空格
- 多個連續的 · 合併為一個
- 空括號會被移除

版本：
20251218:  初版,實現單字拆分注解功能.
           添加詞語編碼注解功能,支持前4字和末字顯示.
20251222:  添加字根全編碼支持,通過 chaifen_code_all_roots 配置控制數據格式(6欄/7欄).
           新增 lv2d 模式(二重詳解),使用字根全編碼替代普通編碼.
           為不同注解級別添加視覺標記(🈩/🈔/🈔🈖/🈕).
           新增 max_code_length 配置,動態控制詞語顯示前N-1字和末1字編碼.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

local core = require("yuhao.yuhao_core")

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
輔助函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
將 UTF-8 字符串分割成單個字符的數組
  @param str: 要分割的 UTF-8 字符串
  @return: 包含各個 UTF-8 字符的數組
]]
local function utf8chars(str)
  local chars = {}
  for pos, code in utf8.codes(str) do
    chars[#chars + 1] = utf8.char(code)
  end
  return chars
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
格式化與解析函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
格式化拆分信息字符串
  將原始格式轉換為易讀格式：
  - 拼音中的 _ 轉換為空格
  - 多個 · 合併為一個
  - 移除空括號
  
  @param str: 原始字符串
  @return: 格式化後的字符串
]]
local function format_string(str)
  if str == '' then return str end
  
  return str
    :gsub('_', ' ')                    -- 下劃線轉空格
    :gsub(' ·  ·  · ', ' · ')         -- 合併多個分隔符
    :gsub(' ·  · ', ' · ')
    :gsub('〔 · 〕', '')                -- 移除空括號
    :gsub('〔〕', '')
    :gsub('〔 · ', '〔')               -- 移除開頭多餘的分隔符
    :gsub(' · 〕', '〕')               -- 移除結尾多餘的分隔符
end

--[[
解析反查數據庫返回的拆分數據
  若 has_all_roots_code 為 true，數據格式: [拆分,編碼,字根全編碼,拼音,注釋,字符集,Unicode] (7欄)
  若 has_all_roots_code 為 false，數據格式: [拆分,編碼,拼音,注釋,字符集,Unicode] (6欄)
  
  @param raw_data: 反查數據庫返回的原始字符串
  @param has_all_roots_code: 是否包含字根全編碼欄位
  @return: 包含各個字段的表，如果解析失敗則返回 nil
]]
local function parse_chaifen_data(raw_data, has_all_roots_code)
  if not raw_data or raw_data == '' then
    return nil
  end
  
  -- 移除首尾的方括號
  local content = raw_data:match('^%[(.*)%]$')
  if not content then
    return nil
  end
  
  -- 按逗號分割（這裡假設字段內部不含逗號）
  local parts = {}
  for part in content:gmatch('[^,]+') do
    table.insert(parts, part)
  end
  
  -- 確保至少有基本字段
  if #parts < 2 then
    return nil
  end
  
  -- 根據是否有字根全編碼決定如何解析
  if has_all_roots_code then
    -- 7 欄格式
    return {
      chaifen = parts[1] or '',       -- 拆分
      code = parts[2] or '',          -- 編碼
      code_all_roots = parts[3] or '', -- 字根全編碼
      pinyin = parts[4] or '',        -- 拼音
      comment = parts[5] or '',       -- 注釋
      charset = parts[6] or '',       -- 字符集
      unicode = parts[7] or ''        -- Unicode
    }
  else
    -- 6 欄格式
    return {
      chaifen = parts[1] or '',       -- 拆分
      code = parts[2] or '',          -- 編碼
      code_all_roots = '',            -- 無字根全編碼
      pinyin = parts[3] or '',        -- 拼音
      comment = parts[4] or '',       -- 注釋
      charset = parts[5] or '',       -- 字符集
      unicode = parts[6] or ''        -- Unicode
    }
  end
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
注解生成函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
為單個漢字生成拆分注解
  根據當前選中的注解級別，生成相應詳細程度的注解
  
  @param cand: 候選詞對象 (Candidate)
  @param env: 環境對象，包含引擎和數據庫
  @param rvdb: 反查數據庫對象
  @return: 生成的注解字符串，或 nil（如果無法生成）
]]
local function get_single_char_comment(cand, env, rvdb)
  local text = cand.text
  
  -- 只處理單個字符
  if not core.is_single_char(text) then
    return nil
  end
  
  -- 從反查數據庫獲取拆分數據
  local raw_data = rvdb:lookup(text)
  if not raw_data or raw_data == '' then
    return nil
  end
  
  -- 解析拆分數據
  local data = parse_chaifen_data(raw_data, env.has_all_roots_code)
  if not data then
    return nil
  end
  
  local context = env.engine.context
  
  -- 根據級別返回不同的注解
  if context:get_option('yuhao_chaifen.lv1') then
    -- 一重注解：僅拆分
    return format_string('〔' .. data.chaifen .. '〕')
    
  elseif context:get_option('yuhao_chaifen.lv2') then
    -- 二重注解：拆分 + 編碼
    local parts = {}
    if data.chaifen ~= '' then table.insert(parts, data.chaifen) end
    if data.code ~= '' then table.insert(parts, data.code) end
    return format_string('〔' .. table.concat(parts, ' · ') .. '〕')
    
  elseif context:get_option('yuhao_chaifen.lv2d') then
    -- 二重詳解：拆分 + 編碼 + 字根全編碼（同時顯示 code 和 code_all_roots）
    local parts = {}
    if data.chaifen ~= '' then table.insert(parts, data.chaifen) end
    if data.code ~= '' then table.insert(parts, data.code) end
    if data.code_all_roots ~= '' then table.insert(parts, data.code_all_roots) end
    return format_string('〔' .. table.concat(parts, ' · ') .. ' 🈖〕')
    
  elseif context:get_option('yuhao_chaifen.lv3') then
    -- 多重注解：完整信息
    local parts = {}
    if data.chaifen ~= '' then table.insert(parts, data.chaifen) end
    if data.code ~= '' then table.insert(parts, data.code) end
    if data.pinyin ~= '' then table.insert(parts, data.pinyin) end
    if data.charset ~= '' then table.insert(parts, data.charset) end
    if data.unicode ~= '' then table.insert(parts, data.unicode) end
    return format_string('〔' .. table.concat(parts, ' · ') .. '〕')
  end
  
  return nil
end

--[[
為詞語生成編碼注解
  顯示詞語中每個字的編碼：
  - 少於max_code_length個字：顯示所有字的編碼
  - max_code_length個或更多字：顯示前N-1個字和最後1個字的編碼，中間用 ... 表示省略
  - 字與字之間用 · 分隔（省略號兩側不加 ·）
  
  例如（max_code_length=5）：
  - "一二三四" → 〔Fi · Rje · Hsa · NwPe〕
  - "一二三四五六" → 〔Fi · Rje · Hsa · NwPe ... Dji〕
  
  @param cand: 候選詞對象 (Candidate)
  @param env: 環境對象，包含引擎和數據庫
  @param rvdb: 反查數據庫對象
  @return: 生成的注解字符串，或 nil（如果無法生成）
]]
local function get_phrase_comment(cand, env, rvdb)
  local text = cand.text
  local chars = utf8chars(text)
  local char_count = #chars
  
  -- 只處理多字詞語
  if char_count <= 1 then
    return nil
  end
  
  -- 根據級別決定是否顯示詞語注解
  local context = env.engine.context
  
  -- 只有在 lv2、lv2d 和 lv3 級別才顯示詞語編碼
  if not (context:get_option('yuhao_chaifen.lv2') or context:get_option('yuhao_chaifen.lv2d') or context:get_option('yuhao_chaifen.lv3')) then
    return nil
  end
  
  -- 收集每個字的編碼
  local codes = {}
  local positions_to_show = {}
  
  -- 確定要顯示哪些位置的字
  local max_len = env.max_code_length or 5  -- 預設為 5
  if char_count < max_len then
    -- 少於max_code_length個字：顯示所有
    for i = 1, char_count do
      table.insert(positions_to_show, i)
    end
  else
    -- max_code_length個或更多字：顯示前N-1個和最後1個
    for i = 1, max_len - 1 do
      table.insert(positions_to_show, i)
    end
    table.insert(positions_to_show, char_count)
  end
  
  -- 獲取各個位置字符的編碼
  for _, pos in ipairs(positions_to_show) do
    local char = chars[pos]
    local raw_data = rvdb:lookup(char)
    
    if raw_data and raw_data ~= '' then
      local data = parse_chaifen_data(raw_data, env.has_all_roots_code)
      if data and data.code ~= '' then
        -- 詞語任何模式下都使用普通編碼 code
        table.insert(codes, data.code)
      end
    else
      -- 如果某個字查不到數據，返回 nil
      return nil
    end
    
    -- 在前N-1個字之後、最後一個字之前插入省略號
    local max_len = env.max_code_length or 5
    if char_count >= max_len and pos == max_len - 1 then
      table.insert(codes, '...')
    end
  end
  
  -- 如果沒有收集到任何編碼，返回 nil
  if #codes == 0 then
    return nil
  end
  
  -- 組合成注解字符串
  -- 特殊處理省略號：省略號兩邊不加圓點
  local result = '〔'
  for i, code in ipairs(codes) do
    if i > 1 then
      -- 如果當前項或前一項是省略號，則不加分隔符
      if code == '...' or codes[i-1] == '...' then
        result = result .. ' '
      else
        result = result .. ' · '
      end
    end
    result = result .. code
  end
  result = result .. '〕'
  
  return result
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
過濾器核心函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
過濾器主函數 - 遍歷所有候選詞並添加拆分注解
  這是 Rime lua_filter 的實現函數
  
  工作流程：
  1. 檢查功能是否被關閉（yuhao_chaifen.off）
  2. 根據配置選擇使用大陸或臺灣標準的反查數據庫
  3. 遍歷所有候選詞，根據類型添加相應的注解
  4. 逐個 yield 修改後的候選詞
  
  @param input: 翻譯結果流 (Translation)，包含所有候選詞
  @param env: 環境對象，包含以下重要屬性：
    - engine: Rime 引擎對象
    - rvdb: 反查數據庫對象（大陸標準）
    - rvdb_tw: 反查數據庫對象（台灣標準）
]]
local function filter(input, env)
  local context = env.engine.context
  
  -- 如果關閉了拆分功能，直接傳遞所有候選詞
  if context:get_option('yuhao_chaifen.off') then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end
  
  -- 根據 yuhao_chaifen_source 選項選擇使用大陸標準或台灣標準的反查數據庫
  -- 當 yuhao_chaifen_source 選項開啟時，使用台灣標準；否則使用大陸標準
  local rvdb = nil
  if context:get_option('yuhao_chaifen_source') then
    rvdb = env.rvdb_tw
  else
    rvdb = env.rvdb
  end
  
  -- 遍歷並處理每個候選詞
  for cand in input:iter() do
    local chaifen_comment = nil
    
    -- 先嘗試作為單字處理
    if core.is_single_char(cand.text) then
      chaifen_comment = get_single_char_comment(cand, env, rvdb)
    else
      -- 否則作為詞語處理
      chaifen_comment = get_phrase_comment(cand, env, rvdb)
    end
    
    -- 如果有拆分注解，添加到候選詞
    if chaifen_comment and chaifen_comment ~= '' then
      -- 將拆分注解添加到原有注解之前
      cand.comment = chaifen_comment .. cand.comment
    end
    
    yield(cand)
  end
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
初始化函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
初始化環境，載入必要的數據庫和配置
  這個函數在過濾器初始化時被調用（lua_filter 的 init 方法）
  
  工作內容：
  1. 從 schema 配置中讀取數據庫文件名（大陸標準和臺灣標準）
  2. 載入反查數據庫（.reverse.bin 文件）
  3. 讀取配置項目（chaifen_code_all_roots、max_code_length）
  
  @param env: 環境對象，用於存儲初始化結果
]]
local function init(env)
  -- 從 schema 配置中讀取數據庫文件名
  -- 配置路徑: schema_name/chaifen (大陸標準)
  -- 配置路徑: schema_name/chaifen_tw (台灣標準)
  local db_name = env.engine.schema.config:get_string('schema_name/chaifen')
  local db_name_tw = env.engine.schema.config:get_string('schema_name/chaifen_tw')
  
  if not db_name or db_name == '' then
    -- 如果未配置，使用默認值或回退方案
    db_name = 'yuling_chaifen'
  end
  
  -- 載入大陸標準反查數據庫（.reverse.bin 文件在 build/ 目錄下）
  env.rvdb = ReverseDb('build/' .. db_name .. '.reverse.bin')
  
  -- 載入台灣標準反查數據庫（如果配置了的話，否則使用大陸標準）
  if db_name_tw and db_name_tw ~= '' then
    env.rvdb_tw = ReverseDb('build/' .. db_name_tw .. '.reverse.bin')
  else
    env.rvdb_tw = env.rvdb  -- 回退到大陸標準
  end
  
  -- 讀取 chaifen_code_for_all_roots 配置，決定數據是 7 欄還是 6 欄
  env.has_all_roots_code = env.engine.schema.config:get_bool('schema_name/chaifen_code_all_roots') or false
  
  -- 讀取 max_code_length 配置，決定詞語顯示前 N-1 個字和末 1 個字
  env.max_code_length = env.engine.schema.config:get_int('schema_name/max_code_length') or 5
  
  -- 注：不需要初始化選項，因為選項由方案配置管理
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
模塊導出
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

根據 librime-lua 的要求，返回一個包含過濾器對象的表：
  - init: 初始化函數
  - func: 主邏輯函數
]]
return { init = init, func = filter }