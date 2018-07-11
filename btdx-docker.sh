#!/bin/bash
set -u

DOCKER_REPO="limxtec"
CONFIG="/home/bitcloud/.bitcloud/bitcloud.conf"
CONTAINER_NAME="btdx-masternode"
DEFAULT_PORT="8329"
RPC_PORT="8330"
TOR_PORT="9050"
WEB="bit-cloud.info/files" # without "https://" and without the last "/" (only HTTPS accepted)
BOOTSTRAP="bootstrap.tar.gz"

#
# Color definitions
#
RED='\033[0;31m'
GREEN='\033[0;32m'
NO_COL='\033[0m'
BTDX_COL='\033[0;36m'

#
# Check if bitcloud.conf already exist. Set masternode genkey
#
clear
REUSE="No"
printf "\nDOCKER SETUP FOR ${BTDX_COL}BITCLOUD (BTDX)${NO_COL} MASTERNODE SERVER\n"
printf "\nSetup Config file"
printf "\n-----------------"
if [ -f "$CONFIG" ]
then
        printf "\nFound $CONFIG on your system.\n"
        printf "\nDo you want to re-use this existing config file?\n" 
        printf "Enter [Y]es or [N]o and Hit [ENTER]: "
        read REUSE
fi

if [[ $REUSE =~ "N" ]] || [[ $REUSE =~ "n" ]]; then
        printf "\nFound the following IP-addresses on this Server:\n"
        hostname -I
	printf "\nEnter the IP-address of your ${BTDX_COL}BitCloud${NO_COL} Masternode VPS and Hit [ENTER]: "
        read BTDX_IP
        printf "Enter your ${BTDX_COL}BitCloud${NO_COL} Masternode genkey respond and Hit [ENTER]: "
        read MN_KEY
else
        source $CONFIG
        BTDX_IP=$(echo $externalip)
        MN_KEY=$(echo $masternodeprivkey)
fi

#
# Check distro version for further configurations
#
printf "\nDocker Host Operating System"
printf "\n----------------------------\n"
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi
printf "Found installed $OS $VER\n"

#
# Setup Firewall, install further packages...
#
printf "\nSetup Firewall"
printf "\n--------------\n"

# Configuration for Fedora
if [[ $OS =~ "Fedora" ]] || [[ $OS =~ "fedora" ]] || [[ $OS =~ "CentOS" ]] || [[ $OS =~ "centos" ]]; then
    FIREWALLD=0

    # Check if firewalld is installed
    which firewalld >/dev/null
    if [ $? -eq 0 ]; then
        printf "Found firewall 'firewalld' on your system.\n"
        printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
        printf "\nDo you want to start automated firewall setup?\n"
        printf "Enter [Y]es or [N]o and Hit [ENTER]: "
        read FIRECONF
        
        if [[ $FIRECONF =~ "Y" ]] || [[ $FIRECONF =~ "y" ]]; then

            # Firewall settings
            printf "\nSetup firewall...\n"
            firewall-cmd --permanent --zone=public --add-port=22/tcp
            firewall-cmd --permanent --zone=public --add-port=${DEFAULT_PORT}/tcp
            firewall-cmd --permanent --zone=public --add-port=${RPC_PORT}/tcp
            firewall-cmd --permanent --zone=public --add-port=${TOR_PORT}/tcp
            firewall-cmd --reload
	fi
        FIREWALLD=1
    fi

    if [ $FIREWALLD -ne 1 ]; then
    
        # Check if ufw is installed
        which ufw >/dev/null
        if [ $? -ne 0 ]; then
            if [[ $OS =~ "CentOS" ]] || [[ $OS =~ "centos" ]]; then
                printf "${RED}Missing firewall (firewalld) on your system.${NO_COL}\n"
                printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
                printf "\nDo you want to install firewall (firewalld) and execute automated firewall setup?\n"
                printf "Enter [Y]es or [N]o and Hit [ENTER]: "
                read FIRECONF
                
                if [[ $FIRECONF =~ "Y" ]] || [[ $FIRECONF =~ "y" ]]; then
                    #Installation of ufw, if not installed yet
                    which ufw >/dev/null
                    if [ $? -ne 0 ];then
                        sudo yum install -y firewalld firewall-config
                        systemctl start firewalld.service
                        systemctl enable firewalld.service
                    fi

                    # Firewall settings
                    printf "\nSetup firewall...\n"
                    firewall-cmd --permanent --zone=public --add-port=22/tcp
                    firewall-cmd --permanent --zone=public --add-port=${DEFAULT_PORT}/tcp
                    firewall-cmd --permanent --zone=public --add-port=${RPC_PORT}/tcp
                    firewall-cmd --permanent --zone=public --add-port=${TOR_PORT}/tcp
                    firewall-cmd --reload
                fi
            else
                printf "${RED}Missing firewall (ufw) on your system.${NO_COL}\n"
                printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
                printf "\nDo you want to install firewall (ufw) and execute automated firewall setup?\n"
                printf "Enter [Y]es or [N]o and Hit [ENTER]: "
                read FIRECONF
            fi
        else
            printf "Found firewall 'ufw' on your system.\n"
            printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
            printf "\nDo you want to start automated firewall setup?\n"
            printf "Enter [Y]es or [N]o and Hit [ENTER]: "
            read FIRECONF
        fi

        if [[ $FIRECONF =~ "Y" ]] || [[ $FIRECONF =~ "y" ]]; then
            #Installation of ufw, if not installed yet
            which ufw >/dev/null
            if [ $? -ne 0 ];then
               sudo yum install -y ufw
            fi

            # Firewall settings
            printf "\nSetup firewall...\n"
            ufw logging on
            ufw allow 22/tcp
            ufw limit 22/tcp
            ufw allow ${DEFAULT_PORT}/tcp
            ufw allow ${RPC_PORT}/tcp
            ufw allow ${TOR_PORT}/tcp
            # if other services run on other ports, they will be blocked!
            #ufw default deny incoming
            ufw default allow outgoing
            yes | ufw enable
        fi
    fi

    # Installation further package
    printf "\nPackages Setup"
    printf "\n--------------\n"
    printf "Install further packages...\n"
    sudo yum install -y ca-certificates \
                        curl

    # Start and activate docker
    systemctl start docker.service
    systemctl enable docker.service

# Configuration for Ubuntu/Debian/Mint
elif [[ $OS =~ "Ubuntu" ]] || [[ $OS =~ "ubuntu" ]] || [[ $OS =~ "Debian" ]] || [[ $OS =~ "debian" ]] || [[ $OS =~ "Mint" ]] || [[ $OS =~ "mint" ]]; then
    
    # Check if firewall ufw is installed
    which ufw >/dev/null
    if [ $? -ne 0 ];then
        printf "${RED}Missing firewall (ufw) on your system.${NO_COL}\n"
        printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
        printf "\nDo you want to install firewall (ufw) and execute automated firewall setup?\n"
        printf "Enter [Y]es or [N]o and Hit [ENTER]: "
        read FIRECONF
    else
        printf "Found firewall 'ufw' on your system.\n"
        printf "Automated firewall setup will open the following ports: 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT}\n"
        printf "\nDo you want to start automated firewall setup?\n"
        printf "Enter [Y]es or [N]o and Hit [ENTER]: "
        read FIRECONF
    fi

    if [[ $FIRECONF =~ "Y" ]] || [[ $FIRECONF =~ "y" ]]; then
        # Installation of ufw, if not installed yet
        which ufw >/dev/null
        if [ $? -ne 0 ];then
           apt-get update
           sudo apt-get install -y ufw
        fi

        # Firewall settings
        printf "\nSetup firewall...\n"
        ufw logging on
        ufw allow 22/tcp
        ufw limit 22/tcp
        ufw allow ${DEFAULT_PORT}/tcp
        ufw allow ${RPC_PORT}/tcp
        ufw allow ${TOR_PORT}/tcp
        # if other services run on other ports, they will be blocked!
        #ufw default deny incoming
        ufw default allow outgoing
        yes | ufw enable
    fi

    # Installation further package
    printf "\nPackages Setup"
    printf "\n--------------\n"
    printf "Install further packages...\n"
    apt-get update
    sudo apt-get install -y apt-transport-https \
                            ca-certificates \
                            curl \
                            software-properties-common
else
    printf "Automated firewall setup for $OS ($VER) not supported!\n"
    printf "Please open firewall ports 22, ${DEFAULT_PORT}, ${RPC_PORT} and ${TOR_PORT} manually.\n"
fi

#
# Pull docker images and run the docker container
#
printf "\nStart Docker container"
printf "\n----------------------\n"
sudo docker ps | grep ${CONTAINER_NAME} >/dev/null
if [ $? -eq 0 ];then
    printf "${RED}Conflict! The container name \'${CONTAINER_NAME}\' is already in use.${NO_COL}\n"
    printf "\nDo you want to stop the running container to start the new one?\n"
    printf "Enter [Y]es or [N]o and Hit [ENTER]: "
    read STOP

    if [[ $STOP =~ "Y" ]] || [[ $STOP =~ "y" ]]; then
        docker stop ${CONTAINER_NAME}
    else
	printf "\nDocker Setup Result"
        printf "\n----------------------\n"
        printf "${RED}Canceled the Docker Setup without starting ${BTDX_COL}BitCloud${RED} Masternode Docker Container.${NO_COL}\n\n"
	exit 1
    fi
fi
docker rm ${CONTAINER_NAME} >/dev/null
docker pull ${DOCKER_REPO}/btdx-masternode
docker run -p ${DEFAULT_PORT}:${DEFAULT_PORT} -p ${RPC_PORT}:${RPC_PORT} -p ${TOR_PORT}:${TOR_PORT} --name ${CONTAINER_NAME} -e BTDX_IP="${BTDX_IP}" -e MN_KEY="${MN_KEY}" -e WEB="${WEB}" -e BOOTSTRAP="${BOOTSTRAP}" -v /home/bitcloud:/home/bitcloud:rw -d ${DOCKER_REPO}/btdx-masternode

#
# Show result and give user instructions
#
clear
printf "\nDocker Setup Result"
printf "\n----------------------\n"
sudo docker ps | grep ${CONTAINER_NAME} >/dev/null
if [ $? -ne 0 ];then
    printf "${RED}Sorry! Something went wrong. :(${NO_COL}\n"
else
    printf "${GREEN}GREAT! Your ${BTDX_COL}BitCloud${GREEN} Masternode Docker Container is running now! :)${NO_COL}\n"
    printf "\nShow your running docker container \'${CONTAINER_NAME}\' with 'docker ps'\n"
    sudo docker ps | grep ${CONTAINER_NAME}
    printf "\nJump inside the docker container with 'docker exec -it ${CONTAINER_NAME} bash'\n"
    printf "${GREEN}HAVE FUN!${NO_COL}\n\n"
fi
