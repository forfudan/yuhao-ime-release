# %%

import shutil
import os
from distutils.dir_util import copy_tree
from distutils.dir_util import remove_tree
from shutil import copyfile
import re

version = "v3.9.1-beta.20250724"

# %%
try:
    remove_tree("./dist/yujoy")
except:
    print("Cannot remove dist/yujoy folder!")

try:
    os.makedirs("./dist/yujoy")
except:
    print("Cannot create dist/yujoy folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile(
        "./beta/schema/yuhao/yujoy.full.dict.yaml", "./dist/yujoy.full.dict.yaml"
    )

# %%
shutil.copyfile("./卿雲字根表.pdf", f"./dist/yujoy/卿雲字根表_{version}.pdf")
shutil.copyfile(
    "./卿雲字根按鍵讀音字例表.pdf",
    f"./dist/yujoy/卿雲字根按鍵讀音字例表_{version}.pdf",
)
shutil.copyfile(
    "./changelog.md",
    "./dist/yujoy/changelog.md",
)
shutil.copyfile("./beta/readme.md", "./dist/yujoy/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/fonts/Yuniversus.ttf",
)

copy_tree("./beta/mabiao/", "./dist/yujoy/mabiao/")
copy_tree("./beta/schema/", "./dist/yujoy/schema/")
copy_tree("./beta/custom/", "./dist/yujoy/custom/")
copy_tree("./beta/trime/", "./dist/yujoy/trime/")
copy_tree("./beta/fonts/", "./dist/yujoy/fonts/")

# %%
# copy yuhao
copy_tree("../lua/", "./dist/yujoy/schema/lua/")
for file_name in [
    # "yuhao.symbols.yaml",
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
    "yuhao/yuhao.extended.dict.yaml",
    "yuhao/yuhao.private.dict.yaml",
]:
    copyfile(f"../yulight/beta/schema/{file_name}", f"./dist/yujoy/schema/{file_name}")

copyfile(
    "../yulight/beta/schema/yuhao/yulight.roots.dict.yaml",
    "./dist/yujoy/schema/yuhao/yulight.roots.dict.yaml",
)
copyfile(
    "../yustar/beta/schema/yuhao/yustar.roots.dict.yaml",
    "./dist/yujoy/schema/yuhao/yustar.roots.dict.yaml",
)

for file_name in [
    # "yujoy_tc.schema.yaml",
    # "yujoy_tc.dict.yaml",
    # "yuhao/yujoy_tc.quick.dict.yaml",
    # "yuhao/yujoy_tc.words_literature.dict.yaml",
    # "yuhao/yujoy_tc.words.dict.yaml",
]:
    try:
        os.remove(f"./dist/yujoy/schema/{file_name}")
    except:
        print(f"{file_name} does not exist. It is not deleted.")

# for file_name in [
#     "yujoy_tc.schema.yaml",
# ]:
#     os.remove(f"./dist/yujoy/hotfix/{file_name}")

# %%
shutil.make_archive(f"../dist/卿雲爛兮_{version}", "zip", "./dist/yujoy")
shutil.make_archive(f"../dist/hamster/卿雲爛兮_{version}", "zip", "./dist/yujoy/schema")

# %%
print(f"成功發佈卿雲 {version}！")
