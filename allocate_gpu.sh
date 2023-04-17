#!/bin/bash
OP=$1
CONTAINER=$2
ID=$3

GPUPATH=/var/scripts/gpus

max_hours=96
default_hours=24

function help() {
        cat <<EOF
Usage:
        allocate_gpu show       显示gpu分配情况
        allocate_gpu add [container_name] [gpu_id]      分配指定ID GPU到特定容器
        allocate_gpu remove [container_name] [gpu_id]   从特定容器中移除指定ID GPU
        allocate_gpu help       打印帮助

EOF
}

if [[ -z "$OP" ]]; then
    help
    exit 1
fi

if [[ $OP != "show" && -z "$CONTAINER" ]]; then
    help
    exit 1
fi

if [[ $OP != "show" && -z "$ID" ]]; then
    help
    exit 1
fi

if [ "$ID" -ge 0 ] 2>/dev/null;then
    echo "valid" > /dev/null
else
    if [[ $ID && $ID != "all" ]];then
        echo "gpuId必须为数字"
        exit 1
    fi
fi

gpu_nums=`nvidia-smi -L|wc -l`

if [ $OP == "add" ];then
        if [ $ID == "all" ];then
                {
            for ((i=0;i<gpu_nums;i++))
            do
                if [ -f $GPUPATH/$i ];then
                    echo "GPU$i已经分配给`head -n 1 $GPUPATH/$i`，请尝试其他GPU或联系管理员。"
                    exit 1
                fi
            done
            read -p "请输入分配的时长（单位：小时），最长不超过$max_hours小时，默认为$default_hours小时：" hours
            if [ -z $hours ];then
                hours=$default_hours
            fi
            if [ "$hours" -ge 0 ] 2>/dev/null;then
                if [[ $hours -gt $max_hours || $hours -lt 0 ]];then
                    echo "输入的时长有误"
                    exit 1
                fi
            else
                echo "输入的时长有误"
                exit 1
            fi
            /snap/bin/lxc config device add $CONTAINER gpu gpu
        } && {
            for ((i=0;i<gpu_nums;i++))
            do
                echo $CONTAINER > $GPUPATH/$i
                echo `date +%s` >> $GPUPATH/$i
                echo $hours >> $GPUPATH/$i
            done
        }
        elif [ $(( $ID+1 )) -le $(( $gpu_nums )) ];then
                {
            if [ -f $GPUPATH/$ID ];then
                user=`head -n 1 $GPUPATH/$ID`
                if [ $user != $CONTAINER ];then
                    echo "GPU$ID已经分配给`head -n 1 $GPUPATH/$ID`，请尝试其他GPU或联系管理员。"
                    exit 1
                fi
            fi
            read -p "请输入分配的时长（单位：小时），最长不超过$max_hours小时，默认为$default_hours小时：" hours
            if [ -z $hours ];then
                hours=$default_hours
            fi
            if [ "$hours" -ge 0 ] 2>/dev/null;then
                if [[ $hours -gt $max_hours || $hours -lt 0 ]];then
                    echo "输入的时长有误"
                    exit 1
                fi
            else
                echo "输入的时长有误"
                exit 1
            fi
            if [ ! -f $GPUPATH/$ID ];then
                row=$(( 9+4*$ID ))
                pci=$(nvidia-smi | awk '{print $8}'|sed -n ''$row'p')
                pci=${pci: 4}
                /snap/bin/lxc config device add $CONTAINER gpu$ID gpu pci=$pci
            fi
        } && {
            echo $CONTAINER > $GPUPATH/$ID
            echo `date +%s` >> $GPUPATH/$ID
            echo $hours >> $GPUPATH/$ID
            echo 0 >> $GPUPATH/$ID
            echo 0 >> $GPUPATH/$ID
            }
        else
            echo "gpu id有误"
        fi
elif [ $OP == "remove" ];then
    {
        if [ ! -f $GPUPATH/$ID ];then
            echo "GPU$ID没有分配给任何容器，无需移除。"
            exit 1
        fi
        owner=`head -n 1 $GPUPATH/$ID`
        if [ $owner != $CONTAINER ];then
            echo "GPU$ID没有分配给$CONTAINER，无法移除。"
            exit 1
        fi
        /snap/bin/lxc config device remove $CONTAINER gpu$ID
    } && {
        rm $GPUPATH/$ID
    }
elif [ $OP == "show" ];then
        files=`ls $GPUPATH`
        if [ -z "$files" ];then
                echo "目前所有GPU均未分配！"
        else
                for file in $files
                do
                        printf "\e[96;1mgpu$file：\e[0m\n"
                        user=`head -n 1 $GPUPATH/$file`
                        timestamp=`head -n 2 $GPUPATH/$file|tail -n 1`
                        hours=`head -n 3 $GPUPATH/$file|tail -n 1`

                        now=`date +%s`
                        left=$(( $hours - ($now-$timestamp)/3600 ))
                        printf "\t"$user""
                        if [ $left -le 0 ];then
                            printf "\t\e[91;1m已过期\e[0m\n"
                        else
                            printf "\t剩余时间：$left 小时\n"
                        fi
                done
        fi
else
        help
fi