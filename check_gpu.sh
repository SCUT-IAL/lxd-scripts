###
 # @Author: Houlong
 # @Date: 2022-09-27 15:03:48
 # @LastEditTime: 2022-11-17 09:07:55
 # @LastEditors: Houlong
 # @Description: 定时检查分配GPU的情况，配合crontab使用
 # @FilePath: /lxd-scripts/check_gpu.sh
### 

#!/bin/bash
min_usage=5
min_mem=512
max_overdue=24
max_empty_times=96
warn_period=8

if [ ! -d "/var/scripts/logs" ]; then
    mkdir -p /var/scripts/logs
fi

echo $(date "+%Y-%m-%d %H:%M:%S") 开始检查
gpu_nums=`nvidia-smi -L|wc -l`
for i in `seq $gpu_nums`
do
    i=$(($i - 1))
    if [ -f /var/scripts/gpus/$i ];then
        user=`sed -n '1p' /var/scripts/gpus/$i`
        timestamp=`sed -n '2p' /var/scripts/gpus/$i`
        hours=`sed -n '3p' /var/scripts/gpus/$i`
        empty_times=`sed -n '4p' /var/scripts/gpus/$i`
        last_warn=`sed -n '5p' /var/scripts/gpus/$i`

        now=`date +%s`
        used=$(( ($now-$timestamp)/3600 ))
        after_last_warn=$(( ($now-$last_warn)/3600 ))

        row=$(( 10+4*$i ))
        gpu_mem=`nvidia-smi | awk '{print $9}'| sed -n ''$row'p'`
        gpu_mem=${gpu_mem%MiB}
        gpu_usage=`nvidia-smi | awk '{print $13}'| sed -n ''$row'p'`
        gpu_usage=${gpu_usage%\%}

        # 判断是否连续空闲
        if [ $gpu_usage -lt $min_usage ] && [ $gpu_mem -lt $min_mem ];then
            empty_times=$(($empty_times + 1))
        else
            empty_times=0
        fi
        sed -i '4c '$empty_times'' /var/scripts/gpus/$i

        # 连续空闲超过阈值，自动释放
        if [ $empty_times -ge $max_empty_times ];then
            echo $(date "+%Y-%m-%d %H:%M:%S") GPU$i 连续空闲$max_empty_times次，自动释放
            /var/scripts/allocate_gpu.sh remove $user $i
            continue
        fi

        # 占用GPU超时
        if [ $used -gt $hours ];then
            if [ $(($used - $hours)) -gt $max_overdue ];then
                if [ $gpu_mem -gt $min_mem ] || [ $gpu_usage -gt $min_usage ];then
                    echo $(date "+%Y-%m-%d %H:%M:%S") GPU$i 已超过最大时长，但GPU仍在使用中，无法释放
                else
                    echo $(date "+%Y-%m-%d %H:%M:%S") GPU$i分配给$user，已经超过$max_overdue小时，强制释放
                    /var/scripts/allocate_gpu.sh remove $user $i
                    continue
                fi
            fi
            if [ $after_last_warn -ge $warn_period ];then
                msg="GPU$i分配给$user已经超出$(($used - $hours))小时，请及时释放或重新申请分配，否则将在$max_overdue小时内进行强制释放。"
                echo $(date "+%Y-%m-%d %H:%M:%S") $msg
                echo $msg | mail -s "GPU分配超时提醒" -a "From: 3090-Server <scut_iais@163.com>" `cat /var/scripts/mails/$user`
                sed -i '5c '$now'' /var/scripts/gpus/$i
            fi
        fi
    fi
done
echo $(date "+%Y-%m-%d %H:%M:%S") 结束检查

max_file_size=$((10*1024*1024))
log_path="/var/scripts/logs/"
log_file="check_gpu.log"
cd $log_path
if [ ! -f $log_file ];then
    exit 1
fi
file_size=`ls -l $log_file | awk '{print $5}'`
if [ $file_size -gt $max_file_size ];then
    list=$(ls | sort -r)
    for item in $list; do
        local suffix=${item##*.}
        local prefix=${item%.*}
        expr $(($suffix+0)) 2>&1 > /dev/null
        if [ $? -eq 0 ]; then
            if [ $suffix -lt 11 ]; then
                suffix=$(($suffix+1))
                mv $item $prefix.$suffix
            fi
        else
            mv $item $prefix.$suffix.1
        fi
    done
fi