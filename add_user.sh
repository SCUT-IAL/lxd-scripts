### add user
echo "=====Welcome!"

if [ ! -d /var/scripts/gpus ]; then
    mkdir /var/scripts/gpus
    chmod -R 777 gpus
fi

if [ ! -d /var/scripts/ports ]; then
    mkdir /var/scripts/ports
    chmod -R 777 ports
fi

if [ ! -d /var/scripts/mails ]; then
    mkdir /var/scripts/mails
    chmod -R 777 ports
fi

if [ ! -f /var/scripts/next-port ]; then
    echo 6000 > /var/scripts/next-port
fi

echo "=====Let's setup a new account and create a container now."

read -p "Enter your username: " USERNAME

if [[ -z "$USERNAME" ]]; then
    echo "Please give me a username"
    exit 1
fi

# create user
echo "Creating user..."
sudo useradd -m -s /bin/bash -G lxd $USERNAME
touch /home/$USERNAME/.hushlogin

printf "Allocating container for \e[96;1m$USERNAME\e[0m...\n"

# config the container
lxc init template-ubuntu18.04 ${USERNAME} -p default

# allocate ssh port
printf "Allocating ssh port... "
PORTFILE=/var/scripts/next-port
PORT=$(cat $PORTFILE)
echo $PORT | sudo tee /var/scripts/ports/$USERNAME
echo $(( $PORT+100 )) | sudo tee $PORTFILE
printf "\e[96;1m$PORT\e[0m\n"

# map uid
# printf "uid $(id $USERNAME -u) 0\ngid $(id $USERNAME -g) 0" | lxc config set $USERNAME raw.idmap -

# public data
lxc storage volume attach default public_data $USERNAME /public_data

# config email
read -p "Enter your email: " EMAIL
echo $EMAIL > /var/scripts/mails/$USERNAME

# password
echo "set public key for $USERNAME"
mkdir -p /home/$USERNAME/.ssh/
read -p "Enter public key: " publickey
echo $publickey > /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh/

echo "Login this host via \`ssh <username>@<host-ip>\` to manage your container."

# bashrc
printf '\nalias login_lxd=/var/scripts/login.sh\n' | sudo tee -a /home/$USERNAME/.bashrc
printf '\nif [[ $- =~ i ]]; then\n    source /var/scripts/login.sh\nfi\n' | sudo tee -a /home/$USERNAME/.bashrc

lxc start ${USERNAME}

echo "Done!"

read -p "Press any key to continue..." -n 1 -r