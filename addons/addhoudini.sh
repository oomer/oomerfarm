#!/bin/bash

# addhoudini.sh

# Installs Houdini on an existing worker
# checks for dependencies 
# requires you have a private s3 object storage
# where the untarred houdini installer is located

installerpath_default=/mnt/s3/houdini/houdini-py3-18.5.759-linux_x86_64_gcc6.3/houdini.install
installereula_default=2021-10-13
installationdir_default=/opt/hfs18.5.759

if ! [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "FAIL: Run this on Linux preferably AlmaLinux 8.x"
        exit
fi

echo -e "\n\e[32mAdds houdini to an existing oomerfarm worker\e[0m"
echo -e "\n\e[32mBy installing Houdini, yoiu accept the EULA\e[0m"
echo -e "\e[32mContinue on\e[0m \e[37m$(hostname)?\e[0m"

read -p "(Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
        echo -e "\n\e[31mFAIL:\e[0m Script aborted because Yes was not entered"
        exit
fi

echo -e "\n\e[36m\e[5mHoudini installer path\e[0m\e[0m"
read -p "(default: $installerpath_default)" installerpath
if [ -z  $installerpath ]; then
	installerpath=$installerpath_default
fi

echo -e "\n\e[36m\e[5mHoudini EULA string\e[0m\e[0m"
read -p "(default: $installereula_default)" installereula
if [ -z  $installereula ]; then
	installereula=$installereula_default
fi

echo -e "\n\e[36m\e[5mHoudini installation directory\e[0m\e[0m"
read -p "(default: $installationdir_default)" installationdir
if [ -z  $installationdir ]; then
	installationdir=$installationdir_default
fi

if ! test -f ${installerpath}; then
        echo -e "\n\e[31mFAIL:\e[0m Cannot connect to /mnt/s3, or houdini install dir is missing"
	exit
fi

os_name=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release)
if [ "$os_name" == "\"Ubuntu\"" ]; then
        echo -e "\e[32mDiscovered $os_name\e[0m. Support of Ubuntu is alpha quality"
        apt -y update
        apt -y install mesa-vulkan-drivers
        apt -y install freeglut3-dev
        apt -y install libffi7
        apt -y install fuse
        ln -s /usr/lib/x86_64-linux-gnu/libffi.so.7 /usr/lib/libffi.so.6
elif [ "$os_name" == "\"AlmaLinux\"" ] || [ "$os_name" == "\"Rocky Linux\"" ]; then
        echo -e "\e[32mDiscovered $os_name\e[0m"
        dnf -y update
        #Houdini dependencies
        dnf install -y ncurses-devel
        dnf install -y ncurses-compat-libs
        dnf install -y mesa-libGLU
        dnf install -y libSM
        dnf install -y libnsl
else
        echo "\e[31mFAIL:\e[0m Unsupported operating system $os_name"
        exit
fi


# Install Houdini
# ===============
bash ${installerpath} --install-houdini --install-license --auto-install --make-dir --no-root-check --no-menus --accept-EULA ${installereula} ${installationdir}
