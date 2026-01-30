--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
yuhao_compatible_chaifen_filter.lua
宇浩兼容拆分過濾器
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
版本: 20260129
作者: 朱宇浩 (forFudan) <dr.yuhao.zhu@outlook.com>
Github: https://github.com/forFudan/
版權聲明：
專爲宇浩輸入法製作 <https://shurufa.app>
轉載請保留作者名和出處
Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
介紹:
本過濾器用於屏蔽僅在臺灣標準下纔有的編碼候選詞.

工作邏輯:
對於單字候選詞 X:
  1. 從 schema_name/chaifen 表中獲取編碼 X1 (轉小寫)
  2. 從 schema_name/chaifen_tw 表中獲取編碼 X2 (轉小寫)
  3. 如果 X1 == X2, 說明編碼在不同字形標準下一致, 輸出該字
  4. 如果 X1 != X2, 說明編碼在不同字形標準下不一致:
     - 若當前輸入 input == X2, 則不輸出該候選詞 (屏蔽僅臺標編碼)
     - 其他情況輸出該字

簡言之: 僅當 X1 != X2 且 input == X2 時, 屏蔽該候選詞.

版本歷史:
20260129:  初版, 實現兼容拆分過濾功能.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

local core = require("yuhao.yuhao_core")

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
輔助函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
解析反查數據庫返回的拆分數據, 提取編碼欄位
  數據格式: [拆分,編碼,字根全編碼,拼音,注釋,字符集,Unicode] (7欄)
       或: [拆分,編碼,拼音,注釋,字符集,Unicode] (6欄)

  @param raw_data: 反查數據庫返回的原始字符串
  @return: 編碼字符串, 如果解析失敗則返回 nil
]]
local function parse_code_from_data(raw_data)
  if not raw_data or raw_data == '' then
    return nil
  end

  -- 移除首尾的方括號
  local content = raw_data:match('^%[(.*)%]$')
  if not content then
    return nil
  end

  -- 提取第二欄（編碼欄位）
  local first_comma = content:find(',', 1, true)
  if not first_comma then
    return nil
  end

  local second_comma = content:find(',', first_comma + 1, true)
  if not second_comma then
    return nil
  end

  -- 第二欄就是編碼
  local code = content:sub(first_comma + 1, second_comma - 1)
  return code
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
過濾器核心函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
過濾器主函數 - 屏蔽僅在臺灣標準下纔有的編碼候選詞

  工作流程:
  1. 獲取當前輸入串 (input)
  2. 對於每個單字候選詞:
     a. 從大陸標準數據庫獲取編碼 X1
     b. 從臺灣標準數據庫獲取編碼 X2
     c. 如果 X1 != X2 且 input == X2, 則屏蔽該候選詞
     d. 其他情況輸出候選詞
  3. 詞語候選詞直接輸出

  @param input: 翻譯結果流 (Translation), 包含所有候選詞
  @param env: 環境對象, 包含:
    - engine: Rime 引擎對象
    - rvdb: 反查數據庫對象 (大陸標準)
    - rvdb_tw: 反查數據庫對象 (臺灣標準)
]]
local function filter(input, env)
  local context = env.engine.context

  -- 讀取過濾器開關狀態
  local switch_on = context:get_option("yuhao_compatible_chaifen_filter")

  -- 如果過濾器關閉, 直接傳遞所有候選詞
  if not switch_on then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  -- 獲取當前輸入串
  local current_input = context.input
  if not current_input or current_input == '' then
    -- 沒有輸入, 直接傳遞所有候選詞
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  -- 將輸入轉換爲小寫以便比較
  current_input = string.lower(current_input)

  -- 遍歷並處理每個候選詞
  for cand in input:iter() do
    local should_yield = true

    -- 只處理單字候選詞
    if core.is_single_char(cand.text) then
      local text = cand.text

      -- 從大陸標準數據庫獲取編碼 X1
      local raw_data_sc = env.rvdb:lookup(text)
      local code_sc = parse_code_from_data(raw_data_sc)

      -- 從臺灣標準數據庫獲取編碼 X2
      local raw_data_tw = env.rvdb_tw:lookup(text)
      local code_tw = parse_code_from_data(raw_data_tw)

      -- 如果兩個編碼都存在
      if code_sc and code_tw then
        -- 轉換爲小寫以便比較
        code_sc = string.lower(code_sc)
        code_tw = string.lower(code_tw)

        -- 判斷是否需要屏蔽
        -- 僅當 X1 != X2 且 input == X2 時屏蔽
        if code_sc ~= code_tw and current_input == code_tw then
          should_yield = false
        end
      end
    end

    -- 輸出候選詞（如果沒有被屏蔽）
    if should_yield then
      yield(cand)
    end
  end
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
初始化函數
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

--[[
初始化環境, 載入必要的數據庫

  工作內容:
  1. 從 schema 配置中讀取數據庫文件名
  2. 載入大陸標準反查數據庫 (schema_name/chaifen)
  3. 載入臺灣標準反查數據庫 (schema_name/chaifen_tw)

  @param env: 環境對象, 用於存儲初始化結果
]]
local function init(env)
  -- 從 schema 配置中讀取數據庫文件名
  local db_name = env.engine.schema.config:get_string('schema_name/chaifen')
  local db_name_tw = env.engine.schema.config:get_string('schema_name/chaifen_tw')

  if not db_name or db_name == '' then
    -- 如果未配置, 使用默認值
    db_name = 'yuling_chaifen'
  end

  if not db_name_tw or db_name_tw == '' then
    -- 如果未配置臺灣標準, 使用默認值
    db_name_tw = 'yuling_chaifen_tw'
  end

  -- 載入大陸標準反查數據庫 (.reverse.bin 文件在 build/ 目錄下)
  env.rvdb = ReverseDb('build/' .. db_name .. '.reverse.bin')

  -- 載入臺灣標準反查數據庫
  env.rvdb_tw = ReverseDb('build/' .. db_name_tw .. '.reverse.bin')
end

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
模塊導出
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

根據 librime-lua 的要求, 返回一個包含過濾器對象的表:
  - init: 初始化函數
  - func: 主邏輯函數
]]
return { init = init, func = filter }
