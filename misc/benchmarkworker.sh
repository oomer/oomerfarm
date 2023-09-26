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

unprivileged_account="oomerfarm"

thinkboxurl="https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/2_10.3.0.10/"
thinkboxtar="Deadline-10.3.0.10-linux-installers.tar"

keybundle_url_default="https://drive.google.com/file/d/13xH4vNrr6DSocD9Bhi1cEKl8FU_QIi5K/view?usp=share_link"

nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"

worker_prefix=worker
encryption_passphrase="oomerfarm"
linux_password="oomerfarm"

lighthouse_internet_port="42042"
lighthouse_internet_port_default="42042"
lighthouse_nebula_ip="10.10.0.1"
lighthouse_nebula_ip_default="10.10.0.1"

nebula_version="v1.7.2"
nebula_version_default="v1.7.2"

# Linux and smb user
# ==================
deadline_user="oomerfarm"
deadline_user_default="oomerfarm"
linux_password="oomerfarm"
linux_password_default="oomerfarm"

worker_auto_shutdow=0
worker_name_default=$(hostname)
hub_name_default="i_agree_this_is_unsafe"

# Security best practice #1: add non-privileged/no-shell user to run daemons/systemd units/etc
# Runs deadlinelauncher systemd unit
# Matches uid/gid on remote file server to sync read/write permissions

echo -e "\n==================================================================="
echo -e "Bootstrap this Alma/Rocky Linux machine into an oomerfarm worker"
echo -e "Major changes WILL occur"
echo -e "You agree to the AWS Thinkbox EULA by installing Deadline"
echo -e "==================================================================="
echo -e "Continue on $(hostname)?"
read -p "    (Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
        echo -e "\nScript aborted because Yes was not entered"
        exit
fi

echo -e "\nEnter worker name ( or return for default )"
read -p "( default: $worker_name_default ): " worker_name
if [ -z $worker_name ]; then
    hostnamectl set-hostname "$worker_name_default"
    worker_name="$worker_name_default"
else
    hostnamectl set-hostname "$worker_name"
fi


echo -e "\n\tTEST WAY: Using \"${hub_name_default}\" keybundle is insecure because it is a public set of keys with a knowable passphrase in this source code, by using these keys you acknowledge that anybody else with these same keys can enter your Nebula network. It provides a modicum of security because they would also have to know your server's public internet address"
echo -e "This methods allows rapid deployment to kick the tires and use 100% defaults and 98% fewer challenge questions compared to the \"CORRECT WAY\""
echo -e "\n\tCORRECT WAY: Generate keys on a trusted computer using keyoomerfarm.sh where you personally authorize each and every machine on your network and you control the certificate-authority. Store the encrypted files on Google Drive, shared with \"Anyone with the Link\", hit \"copy link\" button, type \"hub\" below unless you didn't use the keyoomerfarm.sh defaults"
echo -e "\nENTER hub name ( or return for default )"
read -p "    (default: $hub_name_default:) " hub_name
if [ -z "$hub_name" ]; then
	hub_name=$hub_name_default
fi

if ! [ "$hub_name" = "i_agree_this_is_unsafe" ]; then
	echo -e "\nWhat is your keybundle encryption passphrase? ( typing is ghosted )"
	IFS= read -rs encryption_passphrase < /dev/tty
	if [ -z "$encryption_passphrase" ]; then
		echo -e "\nFAIL: Invalid empty passphrase"
		exit
	fi

	echo -e "\nWhat is the Nebula VPN ip you choose for the hub?"
	read -p "    (default: $lighthouse_nebula_ip_default): " lighthouse_nebula_ip
	if [ -z "$lighthouse_nebula_ip" ]; then
	    lighthouse_nebula_ip=$lighthouse_nebula_ip_default
	fi

	echo -e "\nWhat public internet port did you set in the hub?"
	read -p "    (default: $lighthouse_internet_port_default): " lighthouse_internet_port
	if [ -z "$lighthouse_internet_port" ]; then
	    lighthouse_internet_port=$lighthouse_internet_port_default
	fi

	echo -e "\nWould yoy like to chnage the Nebula version?"
	read -p "    (default: $nebula_version_default): " nebula_version
	if [ -z "$nebula_version" ]; then
	    nebula_version=$nebula_version_default
	fi

	#echo -e "\nENTER Nebula firewall group name for render workers..."
	#read -p "    (default: $groupname_nottrusted_default): " groupname_nottrusted
	#if [ -z "$groupname_nottrusted" ]; then
	#    groupname_nottrusted=$groupname_nottrusted_default
	#fi

	#echo -e "\nENTER Nebula firewall group name for trusted computers like laptops and desktops"
	#read -p "    (default: $groupname_trusted_default): " groupname_trusted
	#if [ -z "$groupname_trusted" ]; then
	#    groupname_trusted=$groupname_trusted_default
	#fi

	echo -e "\nFrom bootstraphub.sh what username did you choose for file server connections?"
	read -p "    (default: $deadline_user_default): " deadline_user
	if [ -z "$deadline_user" ]; then
	    deadline_user=$deadline_user_default
	fi

	echo -e "\nFrom bootstraphub.sh what password did you choose for file sharing access"
	echo "Keystrokes hidden, then hit return"
	IFS= read -rs linux_password < /dev/tty
	if [ -z "$linux_password" ]; then
	    echo -e "\nFAIL: Invalid empty password"
	    exit
	fi

	echo -e "\nENTER Google Drive URL to your keybundle"
	read -p "    (default: $keybundle_url_default): " keybundle_url
	if [ -z "$keybundle_url" ]; then
	    keybundle_url=$keybundle_url_default
	fi

else
	keybundle_url=$keybundle_url_default
fi

echo -e "\nEnter public ip address of oomerfarm hub"
read -p "x.x.x.x:" lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
        echo "Cannot continue without public ip address of hub"
        exit
fi


# Security best practice #2: hide passwords as best as possible 
# [ ] never embed passwords inside scripts
# [ ] input via ( hopefully ) invisible ephemeral /dev/tty
# [ ] avoid passing password in command line args which are viewable inside /proc
# [TODO] add a force option to overwrite existing credential, otherwise delete /etc/nebula/smb_credentials to reset
# ====
#while :
#do
#    echo "Enter smb password for DeadlineRepository file sharing, hit return when done"
#    echo "===="
#    IFS= read -rs smb_credentials < /dev/tty
#    echo "Verifying: re-enter password"
#    echo "===="
#    IFS= read -rs smb_check_credentials < /dev/tty
#    if [[ "$smb_credentials" == "$smb_check_credentials" ]]; then
#        break
#    fi
#    echo "Passwords do not match! Try again."
#done

dnf -y install tar

# needed for /usr/local/bin/oomerfarm_shutdown.sh
#dnf -y install sysstat
#systemctl enable --now sysstat

# probe to see if downloadables exist
echo "thinkbox"
if ! ( curl -s --head --fail -o /dev/null ${thinkboxurl}${thinkboxtar} ); then
        echo -e "FAIL: No file found at ${mongourl}${mongotar}"
        exit
fi

# Get Nebula credentials
# ======================
if [[ "$keybundle_url" == *"https://drive.google.com/file/d"* ]]; then
	# if find content-length, then gdrive link is not restricted, this is a guess
	echo "foo$head"
	head=$(curl -s --head ${keybundle_url} | grep "content-length")
	if [[ "$head" == *"content-length"* ]]; then
		# Extract Google uuid 
		googlefileid=$(echo $keybundle_url | egrep -o '(\w|-){26,}')
		echo $head2
		head2=$(curl -s --head -L "https://drive.google.com/uc?export=download&id=${googlefileid}" | grep "content-length")
		if [[ "$head2" == *"content-length"* ]]; then
			echo "Downloading https://drive.google.com/uc?export=download&id=${googlefileid}"
			# [TODO fix hardcoded]
			curl -L "https://drive.google.com/uc?export=download&id=${googlefileid}" -o ${worker_prefix}.keybundle.enc
		else
			echo "FAIL: ${keybundle_url} is not public, Set General Access to Anyone with Link"
			exit
		fi
	else
		echo "FAIL: ${keybundle_url} is not a valid Google Drive link"
		exit
	fi
else
	curl -s -L -O "${keybundle_url}${worker_prefix}.keybundle.enc" 
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

# Store and secure nebula credentials
# ===================================
if ! test -d /etc/nebula; then
	mkdir /etc/nebula
fi
tar --strip-components 1 -xvf ${worker_prefix}.keybundle -C /etc/nebula
chown root.root /etc/nebula/*.crt
chown root.root /etc/nebula/*.key
rm ${worker_prefix}.keybundle


cat <<EOF > /etc/nebula/smb_credentials
username=${deadline_user}
password=${linux_user}
domain=WORKGROUP
EOF
chmod go-rwx /etc/nebula/smb_credentials

#dnf update -y
dnf install tar -y

# Ensure max security
# ===================
test_selinux=$( getenforce )
if [[ "$test_selinux" == "Disabled" ]]; then
	echo -e "/nFAIL: Selinux is disabled, edit /etc/selinux/config"
	echo "==================================================="
	echo "Change SELINUX=disabled to SELINUX=enforcing"
	echo "Reboot ( SELinux chcon on boot drive takes awhile)"
	echo "=================================================="
	exit
fi

firewalld_status=$(systemctl status firewalld)

if [ -z "$firewalld_status" ]; then
	echo "INSTALL firewald"
	dnf -y install firewalld
	systemctl enable --now firewalld
fi

if ! [[ "$firewalld_status" == *"running"* ]]; then
	systemctl enable --now firewalld
fi

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
echo "${deadline_user}:${linux_password}" | chpasswd


# Install Nebula
# ==============
if ! ( test -f /usr/local/bin/nebula ); then
	mkdir -p /etc/nebula
	curl -s -L -O https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz
	MatchFile="$(echo "${nebulasha256} nebula-linux-amd64.tar.gz" | sha256sum --check)"
	if [ "$MatchFile" = "nebula-linux-amd64.tar.gz: OK" ] ; then
	    echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz\n===="
	    tar --skip-old-files -xzf nebula-linux-amd64.tar.gz
	else
	    echo "FAIL: nebula-linux-amd64.tar.gz checksum failed, file possibly maliciously altered on github"
	    exit
	fi
	mv nebula /usr/local/bin/nebula
	chmod +x /usr/local/bin/
	mv nebula-cert /usr/local/bin/
	chmod +x /usr/local/bin/nebula-cert
	chcon -t bin_t /usr/local/bin/nebula # SELinux security clearance
	rm -f nebula-linux-amd64.tar.gz
fi 

#dnf install -y epel-release htop

# Install cifs dependencies
# [TODO] fix kernel mismatch errors with Alma, works fine in Rocky
# ====
echo -e "/nInstalling cifs (smb) client dependencies"
#dnf install -y kernel-modules
dnf install -y cifs-utils
modprobe cifs

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

EOF


# Activate auto shutdown
# ======================
cat <<EOF > /etc/systemd/system/oomerfarm-idle-check.timer
[Unit]
Description=oomerfarm worker idle check timer

[Timer]
OnCalendar=*:0/10:0
Persistent=true
Unit=oomerfarm-idle-shutdown.service

[Install]
WantedBy=timers.target
EOF

systemctl enable --npw oomerfarm-idle-check.timer

cat <<EOF > /etc/systemd/system/oomerfarm-idle-check.shutdown.service
[Unit]
description=Bella idle shutdown service

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/local/bin/oomerfarm_shutdown.sh
EOF

cat <<EOF > /usr/local/bin/oomerfarm_shutdown.sh
#!/bin/bash
uptime=$(awk '{print $1}' /proc/uptime)
if [ ${uptime%.*} -gt 3600 ]; then
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
# ====
mkdir -p /mnt/DeadlineRepository10
mkdir -p /mnt/oomerfarm
grep -qxF "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/DeadlineRepository10 /mnt/DeadlineRepository10 cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab

grep -qxF "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" /etc/fstab || echo "//$lighthouse_nebula_ip/oomerfarm /mnt/oomerfarm cifs rw,noauto,x-systemd.automount,x-systemd.device-timeout=45,nobrl,uid=3000,gid=3000,file_mode=0664,credentials=/etc/nebula/smb_credentials 0 0" >> /etc/fstab

mount /mnt/DeadlineRepository10
mount /mnt/oomerfarm
cp /mnt/oomerfarm/installers/DeadlineClient-10.3.0.10-linux-x64-installer.run .
chmod +x DeadlineClient-10.3.0.10-linux-x64-installer.run 
./DeadlineClient-10.3.0.10-linux-x64-installer.run --mode unattended --unattendedmodeui minimal --repositorydir /mnt$optional_subfolder/DeadlineRepository10  --connectiontype Direct --noguimode true

cat <<EOF > /etc/systemd/system/deadlinelauncher.service 
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


# Install Bella 
# ====
echo -e "\nInstalling bella_cli"
dnf install -y --quiet mesa-vulkan-drivers mesa-libGL
cp /mnt/oomerfarm/installers/bella_cli-23.4.0.tar.gz .
tar -xvf bella_cli-23.4.0.tar.gz 
chmod +x bella_cli
mv bella_cli /usr/local/bin
rm bella_cli-23.4.0.tar.gz
systemctl enable --now deadlinelauncher
