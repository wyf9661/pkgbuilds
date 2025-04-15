#!/bin/bash

# 定义一个函数来执行makepkg -s 操作并处理相关情况
function build_package {
    local dir="$1"
    local pkgbuild_path="$dir/PKGBUILD"
    if [ -f "$pkgbuild_path" ]; then
        echo "开始在文件夹 $dir 中构建软件包..."
        cd "$dir" 
        # 执行makepkg -s命令
        if makepkg -sf --sign; then
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
    local packages=$(find . -name "*.pkg.tar.xz")
    
    if [ -z "$packages" ]; then
        echo "未找到任何软件包文件，无需拷贝操作。"
        return 0
    fi

    for package in $packages; do
        if [ -f "$package" ]; then
            # 提取软件包名称（不含版本号）
            pkgname=$(basename "$package" | sed -E 's/-[0-9]+(\.[0-9]+)*-[0-9]+-x86_64.*\.pkg\.tar\.xz$//')
            
            echo "正在清理目标目录 $target_dir 中的旧版本 $pkgname..."
            # 删除目标目录中所有匹配该软件包名称的旧版本（.pkg.tar.xz 和 .sig）
            find "$target_dir" -name "$pkgname-*.pkg.tar.xz" -delete
            find "$target_dir" -name "$pkgname-*.pkg.tar.xz.sig" -delete
            
            echo "正在使用 rsync 拷贝 $package 到 $target_dir..."
            rsync -avz "$package" "$target_dir"
            
            # 如果存在对应的 .sig 文件，也一起拷贝
            if [ -f "$package.sig" ]; then
                rsync -avz "$package.sig" "$target_dir"
                echo "签名文件 $package.sig 拷贝成功！"
            fi
            
            if [ $? -eq 0 ]; then
                echo "软件包文件 $package 拷贝成功！"
            else
                echo "软件包文件 $package 拷贝失败，请检查权限或目标目录是否存在问题！"
            fi
        else
            echo "软件包文件 $package 不存在，跳过该文件的拷贝操作。"
        fi
    done
}

update_repo_db() {
    local repo_dir="$1"
    local db_name="acoinfo.db.tar.gz"
    
    echo "更新仓库数据库..."
    cd "$repo_dir" || exit 1
    repo-add "$db_name" *.pkg.tar.xz
    echo "数据库已生成：$repo_dir/$db_name"
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
target_copy_dir="/home/ivan/share/x86_64"
# 执行拷贝软件包文件操作
copy_packages "$target_copy_dir"
update_repo_db "$target_copy_dir"
echo "所有操作已完成。"
