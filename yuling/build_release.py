# %%
import os
import re
import shutil
from distutils.dir_util import copy_tree, remove_tree
from shutil import copyfile

version = "v3.10.3-beta.20251222"

# %%
try:
    remove_tree("./dist/yuling")
except:
    print("Cannot remove dist/yuling folder!")

try:
    os.makedirs("./dist/yuling")
except:
    print("Cannot create dist/yuling folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile("./dist/宇浩靈明單字全碼.txt", "./dist/yuling.full.dict.yaml")

# %%
# shutil.copyfile("./yuling.pdf", f"./dist/yuling/yuling_{version}.pdf")
# shutil.copyfile(
#     "./changelog.md",
#     "./dist/yuling/changelog.md",
# )
# shutil.copyfile("./beta/readme.md", f"./dist/yuling/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/fonts/Yuniversus.ttf",
)

copy_tree("./beta/mabiao/", "./dist/yuling/mabiao/")
copy_tree("./beta/schema/", "./dist/yuling/schema/")
copy_tree("./beta/custom/", "./dist/yuling/custom/")
copy_tree("./beta/trime/", "./dist/yuling/trime/")
copy_tree("./beta/fonts/", "./dist/yuling/fonts/")

# %%
# copy yuhao
copy_tree("../lua/", "./dist/yuling/schema/lua/")
for file_name in [
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.extended.dict.yaml",
    "yuhao/yuhao.private.dict.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
]:
    copyfile(f"../yulight/beta/schema/{file_name}", f"./dist/yuling/schema/{file_name}")

for file_name in [
    # "yuhao/yuling_sc.words_tbtu.dict.yaml"
    # "yuling_tc.schema.yaml",
    # "yuling_tc.dict.yaml",
    # "yuhao/yuling_tc.quick.dict.yaml",
    # "yuhao/yuling_tc.words_literature.dict.yaml",
    # "yuhao/yuling_tc.words.dict.yaml",
]:
    try:
        os.remove(f"./dist/yuling/schema/{file_name}")
    except:
        print(f"{file_name} does not exist. It is not deleted.")

# for file_name in [
#     "yuling_tc.schema.yaml",
# ]:
#     os.remove(f"./dist/yuling/hotfix/{file_name}")

# %%
shutil.make_archive(f"../dist/靈明輸入法_{version}", "zip", "./dist/yuling")
shutil.make_archive(
    f"../dist/hamster/靈明輸入法_{version}", "zip", "./dist/yuling/schema"
)

# %%
print(f"成功發佈靈明輸入法 {version}！")

# %%
