#!/bin/bash

# 定义一个函数来执行makepkg -s 操作并处理相关情况
function build_package {
    local dir="$1"
    local pkgbuild_path="$dir/PKGBUILD"
    if [ -f "$pkgbuild_path" ]; then
        echo "开始在文件夹 $dir 中构建软件包..."
        cd "$dir" 
        # 执行makepkg -s命令
        if makepkg -sf; then
            echo "在文件夹 $dir 中软件包构建成功！"
        else
            echo "在文件夹 $dir 中软件包构建失败，请检查相关错误信息！"
        fi
        cd ..
    else
        echo "文件夹 $dir 中不存在PKGBUILD文件，跳过该文件夹的构建操作。"
    fi
}

# 定义函数用于查找并拷贝（使用rsync）软件包文件到指定目录
function copy_packages {
    local target_dir="$1"
    local packages=$(find . -name "*.pkg.tar.zst")
    if [ -z "$packages" ]; then
        echo "未找到任何软件包文件，无需拷贝操作。"
        return 0
    fi
    for package in $packages; do
        if [ -f "$package" ]; then
            echo "正在使用rsync拷贝软件包文件 $package 到 $target_dir..."
            rsync -avz "$package" "$target_dir"
            if [ $? -eq 0 ]; then
                echo "软件包文件 $package 使用rsync拷贝成功！"
            else
                echo "软件包文件 $package 使用rsync拷贝失败，请检查权限或目标目录是否存在问题！"
            fi
        else
            echo "软件包文件 $package 不存在，跳过该文件的拷贝操作。"
        fi
    done
}

# 获取当前目录下所有子文件夹
subfolders=$(find . -maxdepth 1 -type d | grep -v '\.$')

# git clean & git pull

git clean -fd && git fetch && git reset --hard origin/main && git submodule update --remote

# 遍历每个子文件夹并执行构建操作
for subfolder in $subfolders; do
    build_package "$subfolder"
done

# 指定目标拷贝目录，这里是/srv/http，你可以根据实际需求修改
target_copy_dir="/home/ivan/share/os/x86_64"
# 执行拷贝软件包文件操作
copy_packages "$target_copy_dir"

echo "所有操作已完成。"
