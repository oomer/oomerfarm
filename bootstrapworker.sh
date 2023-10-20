#!/bin/bash

# bootstrapworker.sh

# Turns this machine into a renderfarm worker 
# - join existing Nebula virtual private network 
# - with Deadline client software
# - with Bella render plugin
# - optionally with Houdini

# Tested on AWS, Azure, Google, Oracle, Vultr, Digital Ocaan, Linode, Heztner, Server-Factory, Crunchbits

if ! [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "FAIL: Run this on Linux preferably AlmaLinux 8.x"
        exit
fi

thinkboxversion="10.3.0.13"

keybundle_url_default="https://drive.google.com/file/d/13xH4vNrr6DSocD9Bhi1cEKl8FU_QIi5K/view?usp=share_link"

goofysurl="https://github.com/kahing/goofys/releases/download/v0.24.0/goofys"
goofyssha256="729688b6bc283653ea70f1b2b6406409ec1460065161c680f3b98b185d4bf364"

worker_prefix=worker
encryption_passphrase="oomerfarm"

lighthouse_internet_port_default="42042"
lighthouse_internet_port=$lighthouse_internet_port_default
lighthouse_nebula_ip_default="10.10.0.1"
lighthouse_nebula_ip=$lighthouse_nebula_ip_default

skip_advanced_default="yes"
skip_advanced=$skip_advanced_default

nebula_version_default="v1.7.2"
nebula_version=$nebula_version_default
nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"

# Linux and smb user
# ==================
deadline_user_default="oomerfarm"
deadline_user=$deadline_user_default
smb_credentials_default="oomerfarm"
smb_credentials=$smb_credentials_default

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

echo -e "\n\e[32mTurns this machine into a renderfarm worker\e[0m, polls \e[32mhub\e[0m for render jobs"
echo -e "\e[31mWARNING:\e[0m Security changes will break any existing services"
echo -e " - becomes VPN node with address in \e[36m10.10.0.0/16\e[0m subnet"
echo -e " - install Deadline Client \e[37m/opt/Thinkbox/Deadline10\e[0m"
echo -e " - \e[37mfirewall\e[0m blocks ALL non-oomerfarm ports"
echo -e " - enforce \e[37mselinux\e[0m for maximal security"
echo -e " - You agree to the \e[37mAWS Thinkbox EULA\e[0m by installing Deadline"
echo -e " - Optionally mounts \e[37m/mnt/s3\e[0m"
echo -e " - Optionally installs \e[37mHoudini\e[0m"
echo -e "\e[32mContinue on\e[0m \e[37m$(hostname)?\e[0m"

read -p "(Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
        echo -e "\n\e[31mFAIL:\e[0m Script aborted because Yes was not entered"
        exit
fi

echo -e "\e[36m\e[5moomerfarm worker id\e[0m\e[0m"
read -p "Enter number between 1-9999:" worker_id
if (( $worker_id >= 1 && $worker_id <= 9999 )) ; then
	worker_name=$(printf "worker%04d" $worker_id)
	echo ${worker_name}
	hostnamectl --static --transient set-hostname ${worker_name}
	echo ${worker_name}
else
	echo -e "\e[31mFAIL:\e[0m worker id need to be between 1 and 9999 inclusive"
	exit
fi

echo -e "\n\e[36m\e[5mhub internet address\e[0m\e[0m"
read -p "Enter: x.x.x.x:" lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
        echo "Cannot continue without public ip address of hub"
        exit
fi

echo -e "\n\e[32mSecure Method:\e[0m On a trusted computer, generate secret keys ( not this computer ) using \e[36mkeyoomerfarm.sh\e[0m BEFORE running this script. Type \e[36mhub\e[0m below for the secure method"

echo -e "\n\e[32mTest Drive:\e[0m \e[36m${hub_name_default}\e[0m are not-so-secret keys securing oomerfarm with a VPN. Since they allow intrusion without your knowledge only use them to test oomerfarm. Analogy: house keys can be lost and your locks continue to work, BUT a stranger who finds your keys AND knows where you live can easily enter. Hit enter below to use \e[36mi_agree_this_is_unsafe\e[0m with security by obscurity"

echo -e "\nENTER \e[36m\e[5mhub\e[0m\e[0m or \e[36m\e[5m${hub_name_default}\e[0m\e[0m"
read -p "(default: $hub_name_default:) " hub_name
if [ -z "$hub_name" ]; then
	hub_name=$hub_name_default
fi

if ! [ "$hub_name" = "i_agree_this_is_unsafe" ]; then
        # abort if selinux is not enforced
        # selinux provides a os level security sandbox and is very restrictive
        # especially important since renderfarm jobs can included arbitrary code execution on the workers
        test_selinux=$( getenforce )
        if [ "$test_selinux" == "Disabled" ] || [ "$test_selinux" == "Permissive" ];  then
                echo -e "\n\e[31mFAIL:\e[0m Selinux is disabled, edit /etc/selinux/config"
                echo "==================================================="
                echo "Change SELINUX=disabled to SELINUX=enforcing"
                echo -e "then \e[5mREBOOT\e[0m ( SELinux chcon on boot drive takes awhile)"
                echo "=================================================="
                exit
        fi


        echo -e "\nENTER \e[36m\e[5mpassphrase\e[0m\e[0m to decode \e[32mworker.keybundle.enc\e[0m YOU set in \"keyoomerfarm.sh\"  ( keystrokes hidden )"
        IFS= read -rs encryption_passphrase < /dev/tty
        if [ -z "$encryption_passphrase" ]; then
                echo -e "\n\e[31mFAIL:\e[0m Invalid empty passphrase"
                exit
        fi

        echo -e "\n\e[36m\e[5mURL\e[0m\e[0m to \e[32mworker.keybundle.enc\e[0m"
        read -p "Enter: " keybundle_url
        if [ -z "$keybundle_url" ]; then
                echo -e "\e[31mFAIL:\e[0m URL cannot be blank"
                exit
        fi

        echo -e "\n\e[36m\e[5mSkip\e[0m\e[0m advanced setup:"
        read -p "(default: $skip_advanced_default): " skip_advanced
        if [ -z "$skip_advanced" ]; then
            skip_advanced=$skip_advanced_default
        fi

        if ! [[ $skip_advanced == "yes" ]]; then
                echo -e "\n\e[36m\e[5mS3 Endpoint URL\e[0m\e[0m"
                read -p "Enter:" s3_endpoint
                if [ -z  $s3_endpoint ]; then
                        echo "FAIL: s3_endpoint url must be set"
                        exit
                fi

                echo -e "\n\e[36m\e[5mS3 Access Key Id\e[0m\e[0m"
                read -p "Enter:" s3_access_key_id
                if [ -z  $s3_access_key_id ]; then
                        echo "FAIL: s3_access_key_id must be set"
                        exit
                fi

                echo -e "\n\e[36m\e[5mS3 Secret Access Key\e[0m\e[0m"
                read -p "Enter:" s3_secret_access_key
                if [ -z  $s3_secret_access_key ]; then
                        echo "FAIL: s3_secret_access_key must be set"
                        exit
                fi
                mkdir -p /root/.aws
cat <<EOF > /root/.aws/credentials
[default]
aws_access_key_id=${s3_access_key_id}
aws_secret_access_key=${s3_secret_access_key}
EOF
                chmod go-rwx /root/.aws/credentials

                echo -e "\nSet \e[36m\e[5musername\e[0m\e[0m"
		read -p "(default: $deadline_user_default): " deadline_user
		if [ -z "$deadline_user" ]; then
		    deadline_user=$deadline_user_default
		fi

		while :
		do
                    echo -e "\n\e[36m\e[5mpassword\e[0m\e[0m to access hub file server ( keystrokes hidden )"
		    IFS= read -p "(default: oomerfarm)" -rs smb_credentials < /dev/tty
		    if [ -z "$smb_credentials" ]; then
			smb_credentials=$smb_credentials_default
			break
		    else
		        echo "Verifying: re-enter password"
		        IFS= read -rs smb_check_credentials < /dev/tty
		        if [[ "$smb_credentials" == "$smb_check_credentials" ]]; then
			    break
		        fi
		        echo "Passwords do not match! Try again."
		    fi
		done

                echo -e "\nSet VPN \e[36m\e[5mIP address\e[0m\e[0m"
		read -p "(default: $lighthouse_nebula_ip_default): " lighthouse_nebula_ip
		if [ -z "$lighthouse_nebula_ip" ]; then
		    lighthouse_nebula_ip=$lighthouse_nebula_ip_default
		fi

                echo -e "\nSet VPN public \e[36m\e[5mudp port\e[0m\e[0m"
		read -p "(default: $lighthouse_internet_port_default): " lighthouse_internet_port
		if [ -z "$lighthouse_internet_port" ]; then
		    lighthouse_internet_port=$lighthouse_internet_port_default
		fi
	fi
else
	keybundle_url=$keybundle_url_default
fi


firewalld_status=$(systemctl status firewalld)

os_name=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release)
if [ "$os_name" == "\"Ubuntu\"" ]; then
	# [ TODO ] switch from apparmor to selinux
	echo -e "\e[32mDiscovered $os_name\e[0m. Support of Ubuntu is alpha quality"
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
	echo -e "\e[32mDiscovered $os_name\e[0m"
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
	echo "\e[31mFAIL:\e[0m Unsupported operating system $os_name"
	exit
fi

systemctl enable --now sysstat
systemctl enable --now firewalld
echo -e "\e[32mStarting cifs module\e[0m"
modprobe cifs

echo -e "\e[32mDownloading worker.keybundle.enc\e[0m"

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


# decrypt worker.keybundle.enc
# ============================
while :
do
    if openssl enc -aes-256-cbc -pbkdf2 -d -in worker.keybundle.enc -out worker.keybundle -pass file:<( echo -n "$encryption_passphrase" ) ; then
	rm worker.keybundle.enc
        break
    else
        echo "WRONG passphrase entered for worker.keybundle.enc, try again"
        echo "Enter passphrase for worker.keybundle.enc, then hit return"
        echo "==============================================================="
        IFS= read -rs $encryption_passphrase < /dev/tty
    fi 
done  

# nebula credentials
# ==================
if ! test -d /etc/nebula; then
	mkdir -p /etc/nebula
fi
tar --strip-components 1 -xvf worker.keybundle -C /etc/nebula
chown root.root /etc/nebula/*.crt
chown root.root /etc/nebula/*.key
rm worker.keybundle

# smb_credentials
# ===============
cat <<EOF > /etc/nebula/smb_credentials
username=${deadline_user}
password=${smb_credentials}
domain=WORKGROUP
EOF
chmod go-rwx /etc/nebula/smb_credentials

if ! [[ $skip_advanced == "yes" ]]; then
	# aws_credentials
	# ===============
	mkdir -p /root/.aws
cat <<EOF > /root/.aws/credentials
[default]
aws_access_key_id=${s3_access_key_id}
aws_secret_access_key=${s3_secret_access_key}
EOF
	chmod go-rwx /root/.aws/credentials
fi

# ***FIREWALL rules***
# adopting highly restrictive rules to protect network
echo -e "\n\e[32mTurning up Firewall security...\e[0m"
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
firewall-cmd --quiet --zone=public --add-port=42042/udp --permanent
firewall-cmd -q --new-zone nebula --permanent
firewall-cmd -q --zone nebula --add-interface nebula_tun --permanent
firewall-cmd -q --zone nebula --add-service ssh --permanent
firewall-cmd --quiet --reload

# Create user
# ===========
test_user=$( id "${deadline_user}" )
# id will return blank if no user is found
if [ -z "$test_user" ]; then
	echo "CREATE USER:${deadline_user}"
        groupadd -g 3000 ${deadline_user}
        useradd -g 3000 -u 3000 -m ${deadline_user}
fi
echo "${deadline_user}:${smb_credentials}" | chpasswd


# Install Nebula
# ==============
if ! ( test -f /usr/local/bin/nebula ); then
	echo -e "\e[32mDownloading Nebula VPN\e[0m"
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
	if ! [ "$hub_name" = "i_agree_this_is_unsafe" ]; then
		chcon -t bin_t /usr/local/bin/nebula # SELinux security clearance
	fi
	rm -f nebula-linux-amd64.tar.gz
fi 


# Install goofys needed for Houdini and UBL
if ! [[ $skip_advanced == "yes" ]]; then
	if ! ( test -f /usr/local/bin/goofys ); then
		curl -L -o /usr/local/bin/goofys https://github.com/kahing/goofys/releases/download/v0.24.0/goofys
		MatchFile="$(echo "${goofyssha256} /usr/local/bin/goofys" | sha256sum --check)"
		if [ "$MatchFile" = "/usr/local/bin/goofys: OK" ] ; then
			chmod +x /usr/local/bin/goofys
			mkdir -p /mnt/s3
			chown root.root /usr/local/bin/goofys
			if ! [ "$hub_name" = "i_agree_this_is_unsafe" ]; then
				chcon -t bin_t /usr/local/bin/goofys # SELinux security clearance
			fi
		else
			echo "FAIL"
			echo "goofys checksum is wrong, may indicate download failure of malicious alteration"
			exit
		fi
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
systemctl enable nebula.service
systemctl restart nebula.service

# [ TODO ] timers are in but broken
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

# Setup Deadline cifs/smb mount point in /etc/fstab ONLY if it isn't there already
# needs sophisticated grep discovery with echo
# ====
mkdir -p /mnt/DeadlineRepository10
mkdir -p /mnt/oomerfarm
#mkdir -p /mnt/s3

# DeadlineRepository10
# ====================
grep -qxF "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab
mount /mnt/DeadlineRepository10

# oomerfarm smb
# =============
grep -qxF "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab
mount /mnt/oomerfarm

if ! [[ $skip_advanced == "yes" ]]; then
	# s3 goofys
	# =========
	grep -qxF "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" /etc/fstab || echo "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" >> /etc/fstab
	systemctl daemon-reload
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

if ! [[ $skip_advanced == "yes" ]]; then
	# Install Houdini
	# ===============
	bash /mnt/s3/houdini/houdini-py3-18.5.759-linux_x86_64_gcc6.3/houdini.install --install-houdini --install-license --auto-install --make-dir --no-root-check --no-menus --accept-EULA 2021-10-13 /opt/hfs18.5.759

fi
