# %%

from datetime import datetime
import time

# version = datetime.today().strftime('%Y%m%d')
import shutil
import os
from distutils.dir_util import copy_tree
from distutils.dir_util import remove_tree
from shutil import copyfile
import re

version = "v3.10.1"

# %%
try:
    remove_tree("./dist/yustar")
except:
    print("Cannot remove dist/yustar folder!")

try:
    os.makedirs("./dist/yustar")
except:
    print("Cannot create dist/yustar folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile(
        "./beta/schema/yuhao/yustar.full.dict.yaml", f"./dist/yustar.full.dict.yaml"
    )

# %%
# Copy yustar
# shutil.copyfile("./星陳字根表.pdf", f"./dist/yustar/星陳字根表_{version}.pdf")
# shutil.copyfile("./星陳字根簡表.pdf", f"./dist/yustar/星陳字根簡表_{version}.pdf")
# shutil.copyfile(
# "./星陳字根按鍵聚類讀音字例表.pdf",
# f"./dist/yustar/星陳字根按鍵聚類讀音字例表_{version}.pdf",
# )
shutil.copyfile("./beta/readme.md", "./dist/yustar/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/fonts/Yuniversus.ttf",
)
shutil.copyfile("../yujoy/beta/schema/yuhao.essay.txt", "./beta/schema/yuhao.essay.txt")

copy_tree("./beta/mabiao/", "./dist/yustar/mabiao/")
copy_tree("./beta/schema/", "./dist/yustar/schema/")
copy_tree("./beta/custom/", "./dist/yustar/custom/")
copy_tree("./beta/trime/", "./dist/yustar/trime/")
copy_tree("./beta/fonts/", "./dist/yustar/fonts/")

# %%
# copy yuhao
copy_tree("../lua/", "./dist/yustar/schema/lua/")
for file_name in [
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.extended.dict.yaml",
    "yuhao/yuhao.private.dict.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
]:
    copyfile(f"../yulight/beta/schema/{file_name}", f"./dist/yustar/schema/{file_name}")

# %%
shutil.make_archive(f"../dist/星陳輸入法_{version}", "zip", "./dist/yustar")
# copyfile(f"../dist/宇浩星陳_{version}.zip", f"../dist/yuhao_star_{version}.zip")

shutil.make_archive(
    f"../dist/hamster/星陳輸入法_{version}", "zip", "./dist/yustar/schema"
)

# %%
