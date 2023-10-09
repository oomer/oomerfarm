#!/bin/bash

# bootstrapworker.sh

# Bootstrap a Deadline renderfarm worker on AlmaLinux 8.x
# - join existing Nebula virtual private network 
# - with Deadline client software
# - with Bella render plugin

# Tested on AWS, Azure, Google, Oracle, Vultr, Digital Ocaan, Linode, Heztner, Server-Factory, Crunchbits

if ! [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "FAIL: Run this on Alma or Rocky Linux 8.x"
        exit
fi


thinkboxversion="10.2.1.1"

keybundle_url_default="https://drive.google.com/file/d/13xH4vNrr6DSocD9Bhi1cEKl8FU_QIi5K/view?usp=share_link"

goofysurl="https://github.com/kahing/goofys/releases/download/v0.24.0/goofys"
goofyssha256="729688b6bc283653ea70f1b2b6406409ec1460065161c680f3b98b185d4bf364"

worker_prefix=worker
encryption_passphrase="oomerfarm"

lighthouse_internet_port="42042"
lighthouse_internet_port_default="42042"
lighthouse_nebula_ip="10.10.0.1"
lighthouse_nebula_ip_default="10.10.0.1"

skip_advanced_default="yes"

nebula_version="v1.7.2"
nebula_version_default="v1.7.2"
nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"

# Linux and smb user
# ==================
deadline_user="oomerfarm"
deadline_user_default="oomerfarm"
smb_credentials="oomerfarm"
smb_credentials_default="oomerfarm"

worker_auto_shutdown=0
worker_name_default=$(hostname)
hub_name_default="i_agree_this_is_unsafe"

# Security best practice #1: add non-privileged/no-shell user to run daemons/systemd units/etc
# Runs deadline systemd unit
# Matches uid/gid on remote file server to sync read/write permissions
# Security best practice #2: hide passwords as best as possible 
# [ ] never embed passwords inside scripts
# [ ] input via ( hopefully ) invisible ephemeral /dev/tty
# [ ] avoid passing password in command line args which are viewable inside /proc
# [TODO] add a force option to overwrite existing credential, otherwise delete /etc/nebula/smb_credentials to reset

echo -e "\nMake this machine an oomerfarm worker, automatically joining renderfarm"
echo -e "\tMajor changes WILL occur"
echo -e "\tYou agree to AWS Thinkbox EULA"
read -p "(Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
        echo -e "\nScript aborted because Yes was not entered"
        exit
fi

# Ensure SElinux enforcing is on
# ==============================
test_selinux=$( getenforce )
if [ "$test_selinux" == "Disabled" ] || [ "$test_selinux" == "Permissive" ];  then
	selinux-config-enforcing
	echo "SELinux activated, ( file protection on reboot may take a while )"
	echo "Please reboot machine and re-run this script"
	exit
fi

echo -e "\nWorker name ( return for default, \"worker\" suffix is required for VPN)"
read -p "( default: $worker_name_default ): " worker_name
if [ -z $worker_name ]; then
    hostnamectl set-hostname "$worker_name_default"
    worker_name="$worker_name_default"
else
    hostnamectl set-hostname "$worker_name"
fi

echo -e "\nhub's public ip address"
read -p "x.x.x.x:" lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
        echo "Cannot continue without public ip address of hub"
        exit
fi



echo -e "\n\tTESTDRIVE: Using \"${hub_name_default}\" keybundle is insecure because it is a public set of keys with a knowable passphrase in this source code, by using these keys you acknowledge that anybody else with these same keys can enter your Nebula network. It provides a modicum of security because they would also have to know your server's public internet address"
echo -e "This methods allows rapid deployment to kick the tires and use 100% defaults and 98% fewer challenge questions compared to the \"CORRECT WAY\""
echo -e "\n\tCORRECT WAY: Generate keys on a trusted computer using keyoomerfarm.sh where you personally authorize each and every machine on your network and you control the certificate-authority. Store the encrypted files on Google Drive, shared with \"Anyone with the Link\", hit \"copy link\" button"
echo -e "\nhub name ( return for \"TESTDRIVE\", or type \"hub\" for \"CORRECT WAY\")"
read -p "(default: $hub_name_default:) " hub_name
if [ -z "$hub_name" ]; then
	hub_name=$hub_name_default
fi

if ! [ "$hub_name" = "i_agree_this_is_unsafe" ]; then

	echo -e "\nworker keybundle url:"
	read -p "(URL): " keybundle_url
	if [ -z "$keybundle_url" ]; then
		echo "FAIL: Cannot continue, a keybundle url is required"
		exit
	fi

	echo -e "\nworker keybundle passphrase? ( typing is ghosted )"
	IFS= read -rs encryption_passphrase < /dev/tty
	if [ -z "$encryption_passphrase" ]; then
		echo -e "\nFAIL: Invalid empty passphrase"
		exit
	fi

	echo -e "\nhub's VPN ip:"
	read -p "(default: $lighthouse_nebula_ip_default): " lighthouse_nebula_ip
	if [ -z "$lighthouse_nebula_ip" ]; then
	    lighthouse_nebula_ip=$lighthouse_nebula_ip_default
	fi

	echo -e "\nNebula version:"
	read -p "(default: $nebula_version_default): " nebula_version
	if [ -z "$nebula_version" ]; then
	    nebula_version=$nebula_version_default
	fi

	echo -e "\nhub's public internet port:"
	read -p "(default: $lighthouse_internet_port_default): " lighthouse_internet_port
	if [ -z "$lighthouse_internet_port" ]; then
	    lighthouse_internet_port=$lighthouse_internet_port_default
	fi

	echo -e "\nSamba username:"
	read -p "(default: $deadline_user_default): " deadline_user
	if [ -z "$deadline_user" ]; then
	    deadline_user=$deadline_user_default
	fi

	while :
	do
	    echo "Samba password, hit return when done"
	    IFS= read -rs smb_credentials < /dev/tty
	    echo "Verifying: re-enter password"
	    IFS= read -rs smb_check_credentials < /dev/tty
	    if [[ "$smb_credentials" == "$smb_check_credentials" ]]; then
	        break
	    fi
	    echo "Passwords do not match! Try again."
	done

	echo -e "\nSkip advanced setup:"
	read -p "(default: $skip_advanced_default): " skip_advanced
	if [ -z "$skip_advanced" ]; then
	    skip_advanced=$skip_advanced_default
	fi


else
	keybundle_url=$keybundle_url_default
fi

if ! [ $skip_advanced == "yes" ]; then
	echo -e "\nEnter URL"
	read -p "S3 Endpoint:" s3_endpoint
	if [ -z  $s3_endpoint ]; then
		echo "FAIL: s3_endpoint url must be set"
		exit
	fi

	echo -e "\nEnter"
	read -p "S3 Access Key Id:" s3_access_key_id
	if [ -z  $s3_access_key_id ]; then
		echo "FAIL: s3_access_key_id must be set"
		exit
	fi

	echo -e "\nEnter"
	read -p "S3 Secret Access Key:" s3_secret_access_key
	if [ -z  $s3_secret_access_key ]; then
		echo "FAIL: s3_secret_access_key must be set"
		exit
	fi
fi

firewalld_status=$(systemctl status firewalld)

os_name=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release)
if [ "$os_name" == "\"Ubuntu\"" ]; then
	apt -y update
	#systemctl stop apparmor
	#systemctl disable apparmor
	apt -y install sysstat
	if [ -z "$firewalld_status" ]; then
		apt -y install firewalld
	fi
	#apt -y install policycoreutils selinux-utils selinux-basics
	#selinux-activate
	apt -y  install cifs-utils
	apt -y install mesa-vulkan-drivers 
	apt -y install freeglut3-dev
	apt -y install libffi7
	apt -y install fuse
	ln -s /usr/lib/x86_64-linux-gnu/libffi.so.7 /usr/lib/libffi.so.6
elif [ "$os_name" == "\"AlmaLinux\"" ] || [ "$os_name" == "\"Rocky Linux\"" ]; then
	dnf -y update
	dnf -y install tar
	# needed for /usr/local/bin/oomerfarm_shutdown.sh
	dnf -y install sysstat
	if [ -z "$firewalld_status" ]; then
		dnf -y install firewalld
	fi
	dnf install -y mesa-vulkan-drivers mesa-libGL
	dnf install -y cifs-utils
	dnf install -y fuse
	#Houdini dependencies
	dnf install -y ncurses-compat-lib
	dnf install -y mesa-libGLU
	dnf install -y libSM
	dnf install -y libnsl
else
	echo "FAIL"
	exit
fi

systemctl enable --now sysstat
systemctl enable --now firewalld
modprobe cifs

# Get Nebula credentials
# ======================
if [[ "$keybundle_url" == *"https://drive.google.com/file/d"* ]]; then
	# if find content-length, then gdrive link is not restricted, this is a guess
	head=$(curl -s --head ${keybundle_url} | grep "content-length")
	if [[ "$head" == *"content-length"* ]]; then
		# Extract Google uuid 
		googlefileid=$(echo $keybundle_url | egrep -o '(\w|-){26,}')
		echo $googlefileid
		head2=$(curl -s --head -L "https://drive.google.com/uc?export=download&id=${googlefileid}" | grep "content-length")
		if [[ "$head2" == *"content-length"* ]]; then
			echo "Downloading https://drive.google.com/uc?export=download&id=${googlefileid}"
			# Hack with set curl fails under ubuntu , not sure how it helps
			set -x
			curl -L "https://drive.google.com/uc?export=download&id=$googlefileid" -o ${worker_prefix}.keybundle.enc
			set +x
		else
			echo "FAIL: ${keybundle_url} is not public, Set General Access to Anyone with Link"
			exit
		fi
	else
		echo "FAIL: ${keybundle_url} is not a valid Google Drive link"
		exit
	fi
else
	curl -L -o ${worker_prefix}.keybundle.enc "${keybundle_url}" 
fi

while :
do
    if openssl enc -aes-256-cbc -pbkdf2 -d -in ${worker_prefix}.keybundle.enc -out ${worker_prefix}.keybundle -pass file:<( echo -n "$encryption_passphrase" ) ; then
	rm ${worker_prefix}.keybundle.enc
        break
    else
        echo "WRONG passphrase entered for ${worker_prefix}.keybundle.enc, try again"
        echo "Enter passphrase for ${worker_prefix}.keybundle.enc, then hit return"
        echo "==============================================================="
        IFS= read -rs $encryption_passphrase < /dev/tty
    fi 
done  

# nebula credentials
# ==================
if ! test -d /etc/nebula; then
	mkdir /etc/nebula
fi
tar --strip-components 1 -xvf ${worker_prefix}.keybundle -C /etc/nebula
chown root.root /etc/nebula/*.crt
chown root.root /etc/nebula/*.key
rm ${worker_prefix}.keybundle

# smb_credentials
# ===============
cat <<EOF > /etc/nebula/smb_credentials
username=${deadline_user}
password=${smb_credentials}
domain=WORKGROUP
EOF
chmod go-rwx /etc/nebula/smb_credentials

if ! [ $skip_advanced = "yes" ]; then
	# aws_credentials
	# ===============
	mkdir /root/.aws
cat <<EOF > /root/.aws/credentials
[default]
aws_access_key_id=${s3_access_key_id}
aws_secret_access_key=${s3_secret_access_key}
EOF
	chmod go-rwx /root/.aws/credentials
fi

# Security lockdown with firewalld
# Wipe all services and ports except ssh and 22/tcp, may break your system
for systemdservice in $(firewall-cmd --list-services);
do 
	if ! [[ "$systemdservice" == "ssh" ]]; then
		firewall-cmd -q --remove-service ${systemdservice} --permanent
	fi
done
for systemdport in $(firewall-cmd --list-ports);
do 
	if ! [[ "$systemdport" == "22/tcp" ]]; then
		firewall-cmd -q --remove-port ${systemdport} --permanent
	fi
done
firewall-cmd -q --reload

# Create user
# ===========
test_user=$( id "${deadline_user}" )
# id will return blank if no user is found
if [ -z "$test_user" ]; then
	echo "CREATE USER:${deadeline_user}"
        groupadd -g 3000 ${deadline_user}
        useradd -g 3000 -u 3000 -m ${deadline_user}
fi
echo "${deadline_user}:${smb_credentials}" | chpasswd


# Install Nebula
# ==============
if ! ( test -f /usr/local/bin/nebula ); then
	curl -s -L -O https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz
	MatchFile="$(echo "${nebulasha256} nebula-linux-amd64.tar.gz" | sha256sum --check)"
	if [ "$MatchFile" = "nebula-linux-amd64.tar.gz: OK" ] ; then
	    echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz\n===="
	    tar --skip-old-files -xzf nebula-linux-amd64.tar.gz
	else
	    echo "FAIL: nebula-linux-amd64.tar.gz checksum failed, incomplete download or maliciously altered on github"
	    exit
	fi
	mv nebula /usr/local/bin/nebula
	chmod +x /usr/local/bin/
	mv nebula-cert /usr/local/bin/
	chmod +x /usr/local/bin/nebula-cert
	chcon -t bin_t /usr/local/bin/nebula # SELinux security clearance
	rm -f nebula-linux-amd64.tar.gz
fi 

# Install goofys after sha256 checksum security check
# ===================================================
if ! ( test -f /usr/local/bin/goofys ); then
	curl -L -o /usr/local/bin/goofys https://github.com/kahing/goofys/releases/download/v0.24.0/goofys
	MatchFile="$(echo "${goofyssha256} /usr/local/bin/goofys" | sha256sum --check)"
	if [ "$MatchFile" = "/usr/local/bin/goofys: OK" ] ; then
		chmod 755 /user/local/bin/goofys
		chown root.root /usr/local/bin
		chcon -t bin_t /usr/local/bin/goofys # SELinux security clearance
	else
		echo "FAIL"
		echo "goofys checksum is wrong, may indicate download failure of malicious alteration"
		exit
	fi
fi

# Install cifs dependencies
# [TODO] fix kernel mismatch errors with Alma, works fine in Rocky
# ====
#echo -e "/nInstalling cifs (smb) client dependencies"
#dnf install -y kernel-modules

# Create Nebula systemd unit 
# ====
cat <<EOF > /etc/systemd/system/nebula.service
[Unit]
Description=Nebula Launcher Service with dynamically chosen certificates 
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=35
ExecStartPre=/bin/bash -c 'sed -i "s/cert.*/cert: \/etc\/nebula\/\$HOSTNAME.crt/g" /etc/nebula/config.yml'
ExecStartPre=/bin/bash -c 'sed -i "s/key.*/key: \/etc\/nebula\/\$HOSTNAME.key/g" /etc/nebula/config.yml'
ExecStart=/usr/local/bin/nebula -config /etc/nebula/config.yml
ExecStartPost=/bin/sleep 2

[Install]
WantedBy=multi-user.target
EOF

# Write config file
# Security best practices #3: strict firewall rules
# outbound nebula traffic limited to Deadline host
# inbound rules to protect
# use port 42042 to avoid conflict if using dnclient simultaneouly
# =
cat <<EOF > /etc/nebula/config.yml
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/REPLACE.crt
  key: /etc/nebula/REPLACE.key
static_host_map:
  "$lighthouse_nebula_ip": ["$lighthouse_internet_ip:${lighthouse_internet_port}"]
lighthouse:
  am_lighthouse: false
  interval: 60
host:
    - "${lighthouse_nebula_ip}"
listen:
  host: 0.0.0.0
  port: 4242
punchy:
  punch: true
relay:
  am_relay: false
  use_relays: false
tun:
  disabled: false
  dev: nebula_tun
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
logging:
  level: info
  format: text
firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: icmp
      host: any

    - port: 22
      proto: tcp
      groups:
        - oomerfarm
        - oomerfarm-admin

    - port: 1714
      proto: tcp
      groups:
        - oomerfarm

    - port: 1715
      proto: tcp
      groups:
        - oomerfarm

    - port: 1716
      proto: tcp
      groups:
        - oomerfarm
EOF
chmod go-rwx /etc/nebula/config.yml


cat <<EOF > /etc/systemd/system/oomerfarm-shutdown.timer
[Unit]
Description=oomerfarm worker idle check timer

[Timer]
OnCalendar=*:0/10:0
Persistent=true
Unit=oomerfarm-shutdown.service

[Install]
WantedBy=timers.target
EOF

cat <<EOF > /etc/systemd/system/oomerfarm-shutdown.service
[Unit]
description=Bella idle shutdown service

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/local/bin/oomerfarm_shutdown.sh
EOF

systemctl enable --now oomerfarm-shutdown.timer


cat <<EOF > /usr/local/bin/oomerfarm_shutdown.sh
#!/bin/bash
uptime=$(awk '{print $1}' /proc/uptime)
if [ ${uptime%.*} -gt 900 ]; then
	/usr/sbin/shutdown now
fi
EOF
chmod +x /usr/local/bin/oomerfarm_shutdown.sh

firewall-cmd --quiet --zone=public --add-port=42042/udp --permanent
firewall-cmd -q --new-zone nebula --permanent
firewall-cmd -q --zone nebula --add-interface nebula_tun --permanent
firewall-cmd -q --zone nebula --add-service ssh --permanent
firewall-cmd --quiet --reload
systemctl enable --now nebula.service

# Setup Deadline cifs/smb mount point in /etc/fstab ONLY if it isn't there already
# needs sophisticated grep discovery with echo
# ====
mkdir -p /mnt/DeadlineRepository10
mkdir -p /mnt/oomerfarm
mkdir -p /mnt/s3

# DeadlineRepository10
# ====================
grep -qxF "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab
mount /mnt/DeadlineRepository10

# oomerfarm smb
# =============
grep -qxF "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab
mount /mnt/oomerfarm

if ! [ $skip_advanced = "yes" ]; then
	# s3 goofys
	# =========
	grep -qxF "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" /etc/fstab || echo "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" >> /etc/fstab
	mount /mnt/s3
fi

cp /mnt/oomerfarm/installers/DeadlineClient-${thinkboxversion}-linux-x64-installer.run .
chmod +x DeadlineClient-${thinkboxversion}-linux-x64-installer.run 
./DeadlineClient-${thinkboxversion}-linux-x64-installer.run --mode unattended --unattendedmodeui minimal --repositorydir /mnt$optional_subfolder/DeadlineRepository10  --connectiontype Direct --noguimode true

cat <<EOF > /etc/systemd/system/deadline.service 
[Unit]
Description=Deadline 10 Launcher Service
After= nebula.service

[Service]
Type=simple
Restart=always
RestartSec=5
User=oomerfarm
LimitNOFILE=200000
ExecStart=/usr/bin/bash -l -c "/opt/Thinkbox/Deadline10/bin/deadlinelauncher -daemon -nogui"
ExecStop=/opt/Thinkbox/Deadline10/bin/deadlinelauncher -shutdownall
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now deadline


# Install Bella 
# ====
echo -e "\nInstalling bella_cli"
cp /mnt/oomerfarm/installers/bella_cli-23.4.0.tar.gz .
tar -xvf bella_cli-23.4.0.tar.gz 
chmod +x bella_cli
mv bella_cli /usr/local/bin
rm bella_cli-23.4.0.tar.gz

# Install Houdini
# ===============
bash /mnt/s3/houdini/houdini-py3-18.5.759-linux_x86_64_gcc6.3/houdini.install --install-houdini --install-license --auto-install --make-dir --no-root-check --no-menus --accept-EULA 2021-10-13 /opt/hfs18.5.759
