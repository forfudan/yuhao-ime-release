# %%

from datetime import datetime
import time

# version = datetime.today().strftime('%Y%m%d')
import shutil
from shutil import copyfile, make_archive
import os
from distutils.dir_util import copy_tree
from distutils.dir_util import remove_tree
import re

version = "v3.9.0-beta.20250601"

# %%
try:
    remove_tree("./dist/yulight")
except:
    print("Cannot remove dist/yulight folder!")

try:
    os.makedirs("./dist/yulight")
except:
    print("Cannot create dist/yulight folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile(
        "./beta/schema/yuhao/yulight.full.dict.yaml", f"./dist/yulight.full.dict.yaml"
    )

# %%
os.makedirs("./dist/yulight/schema/yuhao")
copyfile("./yulight.png", f"./dist/yulight/yulight_{version}.png")
copyfile("./beta/readme.md", f"./dist/yulight/readme.txt")
copyfile("../yujoy/beta/schema/yuhao.essay.txt", f"./beta/schema/yuhao.essay.txt")

copy_tree("./beta/mabiao", "./dist/yulight/mabiao")
copy_tree("./beta/schema", "./dist/yulight/schema")
copy_tree("./beta/trime", "./dist/yulight/trime")
copy_tree("./beta/custom", "./dist/yulight/custom")

copy_tree("../lua/", "./dist/yulight/schema/lua/")

# %%
# Hamster IME
make_archive(f"../dist/hamster/yuhao_light_{version}", "zip", "./dist/yulight/schema")

# %%
# Make zip
make_archive(f"../dist/宇浩光華_{version}", "zip", "./dist/yulight")
# copyfile(f"../dist/宇浩光華_{version}.zip", f"../dist/yuhao_light_{version}.zip")

# %%
