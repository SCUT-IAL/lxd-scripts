#!/bin/bash
trap '' INT

# 帮助函数
function print_help {
    echo
    echo "========== 容器信息 =========="

    INFO=$(lxc info $USER)
    echo "$INFO" | grep RUNNING > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        printf "\e[96;1m你的容器没有在运行。\e[0m\n"
    else
        printf "\e[96;1m你的容器正在运行。\e[0m\n"
    fi
        echo
    show_gpu
    PORT=$(cat /var/scripts/ports/$USER)
    printf "\n========== 使用须知（\e[96;1m必看！！\e[0m） ==========\n"
    printf "如果需要向容器传输数据，请使用scp或sftp。\n"
    printf "使用过程如有疑问，请联系管理员。"
    echo " "
}

# 停止容器
function do_stop {
    echo "========== 正在停止你的容器..."
    lxc stop $USER
}

# 修改公钥
function change_public_key {
    echo "========== 修改公钥（仅为宿主机上的公钥）..."
    vi /home/$USER/.ssh/authorized_keys
}

# 分配端口
function allocate_port {
    echo "========== 将容器端口与宿主机端口进行映射，用于像nginx，jupyter等应用 ..."
    PORT=$(cat /var/scripts/ports/$USER)
    read -p "输入一个端口数字（你可以使用100个端口，即$PORT-$(($PORT+99))），该数字为宿主机上的端口（输入x返回上一步） " input_id
    if [[ $input_id == "x" ]]; then
        return
    fi
    while [[ $input_id -gt $(($PORT+99)) || $input_id -lt $PORT ]]; do
        echo "端口有误。"
        read -p "输入一个端口数字（你可以使用100个端口，即$PORT-$(($PORT+99))），该数字为宿主机上的端口（输入x返回上一步） " input_id
        if [[ $input_id == "x" ]]; then
            return
        fi
    done

    read -p "输入容器内应用需要映射的端口（如nginx应用需映射的端口为：80） " input_port
    if [ "$input_port" -gt 0 ] 2>/dev/null; then
        lxc config device add $USER proxy$input_id proxy listen=tcp:0.0.0.0:$input_id connect=tcp:127.0.0.1:$input_port
        echo "成功。你可以在宿主机$input_id端口访问应用。"
    else
        echo "端口有误！"
    fi
}

# 释放端口
function release_port {
    show_port
    PORT=$(cat /var/scripts/ports/$USER)
    read -p "输入你要取消映射的端口（$PORT-$(($PORT+99))）,输入x返回上一步 " input_id
    if [[ $input_id == "x" ]]; then
        return
    fi
    while [[ $input_id -gt $(($PORT+99)) || $(($input_id)) -lt $PORT ]]; do
        echo "端口有误。"
        read -p "输入你要取消映射的端口（$PORT-$(($PORT+99))）,输入x返回上一步  " input_id
        if [[ $input_id == "x" ]]; then
            return
        fi
    done

    lxc config device remove $USER proxy$input_id
    echo "成功。"
}

# 查看端口
function show_port {
    echo "========== 当前已映射的端口如下："
    lxc config device show $USER|grep -E "proxy[0-9]+" -A 3
}

# 分配GPU
function allocate_gpu {
    echo "========== 分配GPU..."
    read -p "输入你要分配的GPU编号（输入x返回上一步） " gid
    if [ "$gid" == "x" ]; then
        return
    fi
    if [ "$gid" -ge 0 ] 2>/dev/null; then
        /var/scripts/allocate_gpu.sh add $USER $gid
    else
        echo "输入有误！"
    fi
}

# 释放GPU
function release_gpu {
    echo "========== 释放GPU..."
    read -p "输入你要释放的GPU编号（输入x返回上一步） " gid
    if [ "$gid" == "x" ]; then
        return
    fi
    if [ "$gid" -ge 0 ] 2>/dev/null; then
        /var/scripts/allocate_gpu.sh remove $USER $gid
    else
        echo "输入有误！"
    fi
}

# 查看GPU分配情况
function show_gpu {
    echo "========== 当前已分配的GPU如下 ========="
    /var/scripts/allocate_gpu.sh show
}

# 启动容器
function do_start {
    PORT=$(cat /var/scripts/ports/$USER)
    INFO=$(lxc info $USER)
    echo "$INFO" | grep RUNNING > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "========== 启动容器中。。。"
        lxc start $USER

        sleep 3
        echo "容器已启动。"
    else
        echo "你的容器已经在运行中了。"
    fi
    echo
}

# 进入容器
function do_run {
    lxc exec $USER bash
}

# 容器管理菜单
function container_menu {
    echo ""
    echo "========== 容器管理菜单 =========="
    echo "[1] 进入你的容器"
    echo "[2] 启动你的容器"
    echo "[3] 重启你的容器"
    echo "[4] 停止你的容器"
    echo "[5] 获取容器配置"
    echo "[6] 获取容器信息"
    echo "[x] 返回上一级菜单"
    read -p "请输入你的选择：" op
    if [ "$op" == "1" ]; then
        do_run
        container_menu
    elif [ "$op" == "2" ]; then
        do_start
        container_menu
    elif [ "$op" == "3" ]; then
        do_stop
        sleep 2
        do_start
        container_menu
    elif [ "$op" == "4" ]; then
        do_stop
        container_menu
    elif [ "$op" == "5" ]; then
        lxc config show $USER
        container_menu
    elif [ "$op" == "6" ]; then
        lxc info $USER
        container_menu
    elif [ "$op" == "x" ]; then
        menu
    else
        echo "输入有误！"
        container_menu
    fi
}

# 端口管理菜单
function port_menu {
    echo ""
    echo "========== 端口管理菜单 =========="
    echo "[1] 端口映射"
    echo "[2] 取消端口映射"
    echo "[3] 查看已有端口映射"
    echo "[x] 返回上一级菜单"
    read -p "请输入你的选择：" op
    if [ "$op" == "1" ]; then
        allocate_port
        port_menu
    elif [ "$op" == "2" ]; then
        release_port
        port_menu
    elif [ "$op" == "3" ]; then
        show_port
        port_menu
    elif [ "$op" == "x" ]; then
        menu
    else
        echo "输入有误！"
        port_menu
    fi
}

# GPU管理菜单
function gpu_menu {
    echo ""
    echo "========== GPU管理菜单 =========="
    echo "[1] 分配GPU"
    echo "[2] 释放GPU"
    echo "[3] 查看已分配GPU"
    echo "[4] GPU监控"
    echo "[5] CPU监控"
    echo "[x] 返回上一级菜单"
    read -p "请输入你的选择：" op
    if [ "$op" == "1" ]; then
        allocate_gpu
        gpu_menu
    elif [ "$op" == "2" ]; then
        release_gpu
        gpu_menu
    elif [ "$op" == "3" ]; then
        show_gpu
        gpu_menu
    elif [ "$op" == "4" ]; then
        nvtop
        gpu_menu
    elif [ "$op" == "5" ]; then
        htop
        gpu_menu
    elif [ "$op" == "x" ]; then
        menu
    else
        echo "输入有误！"
        gpu_menu
    fi
}


function menu {
    echo ""
    echo "===== 主菜单  ====="
    echo "[1] 进入你的容器"
    echo "[2] 容器状态管理"
    echo "[3] 端口映射管理"
    echo "[4] GPU分配管理"
    echo "[5] 修改公钥"
    echo "[h] 打印帮助信息"
    echo "[x] 离开"
    read -p "输入你的选择： " op
    if [ "$op" == "1" ];
        then do_run
        menu
    elif [ "$op" == "2" ];
        then container_menu
    elif [ "$op" == "3" ];
        then port_menu
    elif [ "$op" == "4" ];
        then gpu_menu
    elif [ "$op" == "5" ];
        then change_public_key
        menu
    elif [ "$op" == "x" ];
        then
        exit 1
    elif [ "$op" == "h" ];
        then
        print_help
        menu
    #elif [[ -z "$op" ]];
    #    then do_start
    else
        echo "========== 未知指令"
        print_help
        menu
    fi
}

printf "你好呀， \e[96;1m$USER\e[0m\n"
print_help
menu

echo "========== 再见！"