# %%
import os
import re
import shutil
from distutils.dir_util import copy_tree, remove_tree
from shutil import copyfile
from datetime import datetime

# 參數設定
PRESET_VERSION = "v3.11.0"

# 方案配置
SCHEMES = {
    "yulight": {
        "name": "yulight",
        "chinese": "光華",
        "copy_essay": True,
    },
    "yustar": {
        "name": "yustar",
        "chinese": "星陳",
        "copy_essay": True,
    },
    "yujoy": {
        "name": "yujoy",
        "chinese": "卿雲",
        "copy_essay": True,
    },
    "yuming": {
        "name": "yuming",
        "chinese": "日月",
        "copy_essay": False,
    },
    "yuling": {
        "name": "yuling",
        "chinese": "靈明",
        "copy_essay": False,
    },
}

# %%
# 手動輸入版本號（如果不輸入則使用自動生成的版本號）
manual_version = input("請輸入版本號 (如 v3.11.0，留空則自動生成): ").strip()
is_official_version = (
    input("是否為測試版本？(輸入official，留空則為beta): ").strip().lower()
)

if manual_version:
    if is_official_version == "official":
        version = manual_version
    else:
        date = datetime.now().strftime("%Y%m%d")
        time = datetime.now().strftime("%H%M%S")
        version = f"{manual_version}-beta.{date}.{time}"
else:
    date = datetime.now().strftime("%Y%m%d")
    time = datetime.now().strftime("%H%M%S")
    version = f"{PRESET_VERSION}-beta.{date}.{time}"

print(f"版本號: {version}")

# %%
# 選擇要打包的方案
print("\n可用的方案:")
scheme_list = list(SCHEMES.keys())
for i, key in enumerate(scheme_list, 1):
    print(f"  {i}. {SCHEMES[key]['chinese']}輸入法 ({key})")
print("  0. 打包全部方案")

scheme_input = input("\n請輸入數字 (0-{0}): ".format(len(scheme_list))).strip()

# 驗證輸入
if (
    not scheme_input.isdigit()
    or int(scheme_input) < 0
    or int(scheme_input) > len(scheme_list)
):
    print(f"錯誤: 請輸入 0 到 {len(scheme_list)} 之間的數字！")
    exit(1)

scheme_choice = int(scheme_input)

# 如果選擇0，打包所有方案
if scheme_choice == 0:
    schemes_to_build = scheme_list
    print("\n開始打包所有方案...")
else:
    schemes_to_build = [scheme_list[scheme_choice - 1]]
    SCHEMA_NAME = SCHEMES[schemes_to_build[0]]["name"]
    CHINESE_NAME = SCHEMES[schemes_to_build[0]]["chinese"]
    print(f"\n開始打包 {CHINESE_NAME}輸入法 ({SCHEMA_NAME}) {version}...")


# %%
def build_scheme(scheme_key, version):
    """打包單個方案"""
    SCHEMA_NAME = SCHEMES[scheme_key]["name"]
    CHINESE_NAME = SCHEMES[scheme_key]["chinese"]
    copy_essay = SCHEMES[scheme_key]["copy_essay"]

    print(f"\n{'=' * 60}")
    print(f"開始打包 {CHINESE_NAME}輸入法 ({SCHEMA_NAME}) {version}...")
    print(f"{'=' * 60}")

    # 清理並創建dist目錄
    try:
        remove_tree(f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}")
    except Exception as e:
        print(f"Cannot remove {SCHEMA_NAME}/dist/{SCHEMA_NAME} folder: {e}")

    try:
        os.makedirs(f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}")
    except Exception as e:
        print(f"Cannot create {SCHEMA_NAME}/dist/{SCHEMA_NAME} folder: {e}")

    # 如果是正式版本，複製完整碼表
    if re.match(r"^v\d+.\d+.\d+$", version):
        try:
            shutil.copyfile(
                f"./{SCHEMA_NAME}/beta/schema/yuhao/{SCHEMA_NAME}.full.dict.yaml",
                f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}.full.dict.yaml",
            )
        except Exception as e:
            print(f"Warning: Cannot copy full dict file for {SCHEMA_NAME}: {e}")

    # 複製基本文件
    print("複製基本文件...")

    # readme
    try:
        shutil.copyfile(
            f"./{SCHEMA_NAME}/beta/readme.md",
            f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/readme.txt",
        )
    except Exception as e:
        print(f"Warning: readme.md not found: {e}")

    # 字體文件直接複製到 dist/fonts
    os.makedirs(f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/fonts/", exist_ok=True)
    try:
        shutil.copyfile(
            "../assets/fonts/Yuniversus.ttf",
            f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/fonts/Yuniversus.ttf",
        )
    except Exception as e:
        print(f"Warning: Cannot copy font file: {e}")

    # essay文件（只有部分方案需要）
    # 源文件在 yujoy 中
    if copy_essay:
        try:
            shutil.copyfile(
                "./yujoy/beta/schema/yuhao.essay.txt",
                f"./{SCHEMA_NAME}/beta/schema/yuhao.essay.txt",
            )
        except Exception as e:
            print(f"Warning: yuhao.essay.txt not found: {e}")

    # 複製目錄
    print("複製目錄...")

    copy_tree(
        f"./{SCHEMA_NAME}/beta/mabiao/",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/mabiao/",
    )
    copy_tree(
        f"./{SCHEMA_NAME}/beta/schema/",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/schema/",
    )
    copy_tree(
        f"./{SCHEMA_NAME}/beta/custom/",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/custom/",
    )
    copy_tree(
        f"./{SCHEMA_NAME}/beta/trime/",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/trime/",
    )

    # 複製lua文件（只複製頂層.lua文件，不包括子目錄）
    print("複製lua文件...")
    os.makedirs(f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/schema/lua/yuhao/", exist_ok=True)

    for file_name in os.listdir("./lua/yuhao/"):
        if file_name.endswith(".lua") and os.path.isfile(
            os.path.join("./lua/yuhao/", file_name)
        ):
            copyfile(
                f"./lua/yuhao/{file_name}",
                f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/schema/lua/yuhao/{file_name}",
            )

    # 複製共用的yaml文件
    print("複製共用yaml文件...")

    yaml_files = [
        "yuhao_pinyin.dict.yaml",
        "yuhao_pinyin.schema.yaml",
        "yuhao/yuhao.extended.dict.yaml",
        "yuhao/yuhao.private.dict.yaml",
        "yuhao/yuhao.symbols.dict.yaml",
        "yuhao/yuhao.symbols_inline.dict.yaml",
    ]

    for file_name in yaml_files:
        try:
            copyfile(
                f"./yulight/beta/schema/{file_name}",
                f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/schema/{file_name}",
            )
        except Exception as e:
            print(f"Warning: Cannot copy {file_name}: {e}")

    # 清除所有 .DS_Store 文件
    print("清除 .DS_Store 文件...")
    for root, dirs, files in os.walk(f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}"):
        for file in files:
            if file == ".DS_Store":
                ds_store_path = os.path.join(root, file)
                try:
                    os.remove(ds_store_path)
                except Exception as e:
                    print(f"无法删除 {ds_store_path}: {e}")

    # 創建dist和hamster目錄（如果不存在）
    os.makedirs("./dist", exist_ok=True)
    os.makedirs("./dist/hamster", exist_ok=True)

    # 打包zip文件
    print("打包zip文件...")

    shutil.make_archive(
        f"./dist/{CHINESE_NAME}輸入法_{version}",
        "zip",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}",
    )

    shutil.make_archive(
        f"./dist/hamster/{CHINESE_NAME}輸入法_{version}",
        "zip",
        f"./{SCHEMA_NAME}/dist/{SCHEMA_NAME}/schema",
    )

    print(f"✓ 成功發佈{CHINESE_NAME}輸入法 {version}！")
    return CHINESE_NAME


# %%
# 執行打包
built_schemes = []
for scheme_key in schemes_to_build:
    try:
        chinese_name = build_scheme(scheme_key, version)
        built_schemes.append(chinese_name)
    except Exception as e:
        print(f"\n✗ 打包 {scheme_key} 時發生錯誤: {e}")
        import traceback

        traceback.print_exc()

# %%
# 顯示最終結果
print(f"\n{'=' * 60}")
print("打包完成！")
print(f"{'=' * 60}")
print(f"版本號: {version}")
print(f"成功打包的方案: {', '.join(built_schemes)}")
print(f"檔案位於: {os.path.abspath('./dist/')}")
for name in built_schemes:
    print(f"  - {name}輸入法_{version}.zip")
    print(f"  - hamster/{name}輸入法_{version}.zip")
