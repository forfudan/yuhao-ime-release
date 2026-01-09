# %%

import shutil
import os
from distutils.dir_util import copy_tree
from distutils.dir_util import remove_tree
from shutil import copyfile
import re
from datetime import datetime

date = datetime.now().strftime("%Y%m%d")
time = datetime.now().strftime("%H%M%S")

version = f"v3.11.0-beta.{date}.{time}"

SCHEMA_NAME = "yujoy"
CHINESE_NAME = "卿雲"

# %%
try:
    remove_tree(f"./dist/{SCHEMA_NAME}")
except:
    print(f"Cannot remove dist/{SCHEMA_NAME} folder!")

try:
    os.makedirs(f"./dist/{SCHEMA_NAME}")
except:
    print(f"Cannot create dist/{SCHEMA_NAME} folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile(
        "./beta/schema/yuhao/{SCHEMA_NAME}.full.dict.yaml",
        f"./dist/{SCHEMA_NAME}.full.dict.yaml",
    )

# %%
shutil.copyfile("./beta/readme.md", f"./dist/{SCHEMA_NAME}/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/fonts/Yuniversus.ttf",
)

copy_tree("./beta/mabiao/", f"./dist/{SCHEMA_NAME}/mabiao/")
copy_tree("./beta/schema/", f"./dist/{SCHEMA_NAME}/schema/")
copy_tree("./beta/custom/", f"./dist/{SCHEMA_NAME}/custom/")
copy_tree("./beta/trime/", f"./dist/{SCHEMA_NAME}/trime/")
copy_tree("./beta/fonts/", f"./dist/{SCHEMA_NAME}/fonts/")

# %%
# copy yuhao lua files (only top level, no subdirectories)
os.makedirs(f"./dist/{SCHEMA_NAME}/schema/lua/yuhao/", exist_ok=True)
for file_name in os.listdir("../lua/yuhao/"):
    if file_name.endswith(".lua") and os.path.isfile(
        os.path.join("../lua/yuhao/", file_name)
    ):
        copyfile(
            f"../lua/yuhao/{file_name}",
            f"./dist/{SCHEMA_NAME}/schema/lua/yuhao/{file_name}",
        )

for file_name in [
    # "yuhao.symbols.yaml",
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
    "yuhao/yuhao.extended.dict.yaml",
    "yuhao/yuhao.private.dict.yaml",
]:
    copyfile(
        f"../yulight/beta/schema/{file_name}",
        f"./dist/{SCHEMA_NAME}/schema/{file_name}",
    )

for file_name in [
    # "yujoy_tc.schema.yaml",
    # "yujoy_tc.dict.yaml",
    # "yuhao/yujoy_tc.quick.dict.yaml",
    # "yuhao/yujoy_tc.words_literature.dict.yaml",
    # "yuhao/yujoy_tc.words.dict.yaml",
]:
    try:
        os.remove(f"./dist/{SCHEMA_NAME}/schema/{file_name}")
    except:
        print(f"{file_name} does not exist. It is not deleted.")

# %%
# 清除所有 .DS_Store 文件
for root, dirs, files in os.walk(f"./dist/{SCHEMA_NAME}"):
    for file in files:
        if file == ".DS_Store":
            ds_store_path = os.path.join(root, file)
            try:
                os.remove(ds_store_path)
                print(f"已删除: {ds_store_path}")
            except Exception as e:
                print(f"无法删除 {ds_store_path}: {e}")

# %%
shutil.make_archive(
    f"../dist/{CHINESE_NAME}輸入法_{version}", "zip", f"./dist/{SCHEMA_NAME}"
)
shutil.make_archive(
    f"../dist/hamster/{CHINESE_NAME}輸入法_{version}",
    "zip",
    f"./dist/{SCHEMA_NAME}/schema",
)

# %%
print(f"成功發佈{CHINESE_NAME} {version}！")
