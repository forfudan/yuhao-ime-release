# %%

import shutil
import os
from distutils.dir_util import copy_tree
from distutils.dir_util import remove_tree
from shutil import copyfile
import re

version = "v3.9.0"

# %%
try:
    remove_tree("./dist/yusm")
except:
    print("Cannot remove dist/yusm folder!")

try:
    os.makedirs("./dist/yusm")
except:
    print("Cannot create dist/yusm folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile(
        "./beta/schema/yuhao/yusm.full.dict.yaml", "./dist/yusm.full.dict.yaml"
    )

# %%
# shutil.copyfile("./yusm.pdf", f"./dist/yusm/yusm_{version}.pdf")
# shutil.copyfile(
#     "./changelog.md",
#     "./dist/yusm/changelog.md",
# )
# shutil.copyfile("./beta/readme.md", f"./dist/yusm/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/font/Yuniversus.ttf",
)

copy_tree("./beta/mabiao/", "./dist/yusm/mabiao/")
copy_tree("./beta/schema/", "./dist/yusm/schema/")
copy_tree("./beta/custom/", "./dist/yusm/custom/")
copy_tree("./beta/trime/", "./dist/yusm/trime/")
copy_tree("./beta/font/", "./dist/yusm/font/")

# %%
# copy yuhao
copy_tree("../lua/", "./dist/yusm/schema/lua/")
for file_name in [
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
]:
    copyfile(f"../yulight/beta/schema/{file_name}", f"./dist/yusm/schema/{file_name}")

# copyfile(
#     "../yulight/beta/schema/yuhao/yulight.roots.dict.yaml",
#     "./dist/yusm/schema/yuhao/yulight.roots.dict.yaml",
# )
# copyfile(
#     "../yustar/beta/schema/yuhao/yustar.roots.dict.yaml",
#     "./dist/yusm/schema/yuhao/yustar.roots.dict.yaml",
# )

# for file_name in [
#     # "yusm_tc.schema.yaml",
#     # "yusm_tc.dict.yaml",
#     # "yuhao/yusm_tc.quick.dict.yaml",
#     # "yuhao/yusm_tc.words_literature.dict.yaml",
#     # "yuhao/yusm_tc.words.dict.yaml",
# ]:
#     try:
#         os.remove(f"./dist/yusm/schema/{file_name}")
#     except:
#         print(f"{file_name} does not exist. It is not deleted.")

# for file_name in [
#     "yusm_tc.schema.yaml",
# ]:
#     os.remove(f"./dist/yusm/hotfix/{file_name}")

# %%
shutil.make_archive(f"../dist/宇浩日月_{version}", "zip", "./dist/yusm")
shutil.make_archive(f"../dist/hamster/宇浩日月_{version}", "zip", "./dist/yusm/schema")

# %%
print(f"成功發佈宇浩日月 {version}！")

# %%
