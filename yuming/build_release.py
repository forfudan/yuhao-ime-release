# %%
import os
import re
import shutil
from distutils.dir_util import copy_tree, remove_tree
from shutil import copyfile

version = "v3.10.3-beta.20251218"

# %%
try:
    remove_tree("./dist/yuming")
except:
    print("Cannot remove dist/yuming folder!")

try:
    os.makedirs("./dist/yuming")
except:
    print("Cannot create dist/yuming folder!")

if re.match(r"^v\d+.\d+.\d+$", version):
    shutil.copyfile("./dist/宇浩日月單字全碼.txt", "./dist/yuming.full.dict.yaml")

# %%
# shutil.copyfile("./yuming.pdf", f"./dist/yuming/yuming_{version}.pdf")
# shutil.copyfile(
#     "./changelog.md",
#     "./dist/yuming/changelog.md",
# )
# shutil.copyfile("./beta/readme.md", f"./dist/yuming/readme.txt")
shutil.copyfile(
    "../../assets/fonts/Yuniversus.ttf",
    "./beta/fonts/Yuniversus.ttf",
)

copy_tree("./beta/mabiao/", "./dist/yuming/mabiao/")
copy_tree("./beta/schema/", "./dist/yuming/schema/")
copy_tree("./beta/custom/", "./dist/yuming/custom/")
copy_tree("./beta/trime/", "./dist/yuming/trime/")
copy_tree("./beta/fonts/", "./dist/yuming/fonts/")

# %%
# copy yuhao
copy_tree("../lua/", "./dist/yuming/schema/lua/")
for file_name in [
    "yuhao_pinyin.dict.yaml",
    "yuhao_pinyin.schema.yaml",
    "yuhao/yuhao.extended.dict.yaml",
    "yuhao/yuhao.private.dict.yaml",
    "yuhao/yuhao.symbols.dict.yaml",
    "yuhao/yuhao.symbols_inline.dict.yaml",
]:
    copyfile(f"../yulight/beta/schema/{file_name}", f"./dist/yuming/schema/{file_name}")

# copyfile(
#     "../yulight/beta/schema/yuhao/yulight.roots.dict.yaml",
#     "./dist/yuming/schema/yuhao/yulight.roots.dict.yaml",
# )
# copyfile(
#     "../yustar/beta/schema/yuhao/yustar.roots.dict.yaml",
#     "./dist/yuming/schema/yuhao/yustar.roots.dict.yaml",
# )

for file_name in [
    "yuhao/yuming_sc.words_tbtu.dict.yaml"
    # "yuming_tc.schema.yaml",
    # "yuming_tc.dict.yaml",
    # "yuhao/yuming_tc.quick.dict.yaml",
    # "yuhao/yuming_tc.words_literature.dict.yaml",
    # "yuhao/yuming_tc.words.dict.yaml",
]:
    try:
        os.remove(f"./dist/yuming/schema/{file_name}")
    except:
        print(f"{file_name} does not exist. It is not deleted.")

# for file_name in [
#     "yuming_tc.schema.yaml",
# ]:
#     os.remove(f"./dist/yuming/hotfix/{file_name}")

# %%
# 清除所有 .DS_Store 文件
for root, dirs, files in os.walk("./dist/yuming"):
    for file in files:
        if file == ".DS_Store":
            ds_store_path = os.path.join(root, file)
            try:
                os.remove(ds_store_path)
                print(f"已删除: {ds_store_path}")
            except Exception as e:
                print(f"无法删除 {ds_store_path}: {e}")

# %%
shutil.make_archive(f"../dist/日月輸入法_{version}", "zip", "./dist/yuming")
shutil.make_archive(
    f"../dist/hamster/日月輸入法_{version}", "zip", "./dist/yuming/schema"
)

# %%
print(f"成功發佈日月輸入法 {version}！")

# %%
