#!/bin/bash
# save as /root/del_user.sh

USERNAME=$1
if [[ -z "$USERNAME" ]]; then
    echo "Please give me a username"
    exit 1
fi

if [ ! -f "/var/scripts/ports/$USERNAME" ]; then
        echo "username does not exist"
        exit 1
fi

echo "This script will"
echo "1. Stop & remove lxc container $USERNAME"
echo "2. userdel -f -r $USERNAME"
echo ""
read -p "Are you sure (y/n)? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    lxc stop $USERNAME
    lxc rm $USERNAME
    rm /var/scripts/ports/$USERNAME
    rm /var/scripts/mails/$USERNAME
    userdel -f -r $USERNAME
    gpu_nums=`nvidia-smi -L|wc -l`
    GPUPATH=/var/scripts/gpus
    for ((i=0; i<=$gpu_nums-1; i ++))
    do
        if [ -f $GPUPATH/$i ];then
            user=`head -n 1 $GPUPATH/$i`
            if [[ $user == $USERNAME ]]; then
                rm $GPUPATH/$i
            fi
        fi
    done
    echo "Done!"
else
    echo "Canceled"
    exit 1
fi