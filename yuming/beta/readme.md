# 宇浩·卿雲

## schema

/scheme 中的文件爲 Rime 輸入法各平臺（小狼毫、鼠鬚管、同文）通用碼表。

複製所有文件到設備中的 /Rime 文件夾。

重新部署後即可使用。

*注意*
如果你不想拷貝 default.custom.yaml 文件，請在其中手動添加本方案名如下：

patch:
  schema_list:
    - schema: yuming          # 大陸簡化字、大陸繁體字、臺灣傳統字、香港傳統字通打
    - schema: yuming_essence  # 無 lua 整句輸入

## trime

/trime 中的文件，用於 Android 平臺的「同文輸入法」。使用時，直接將文件覆蓋 /Rime 文件夾下的原文件即可。

## custom

/custom 中的文件爲 Rime 輸入法各平臺（小狼毫、鼠鬚管）方案的自定義設定。

## mabiao

/mabiao 中的文件是其他平臺的碼表。
