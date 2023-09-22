# bootstrapdeadline.sh

# Bootstrap a Deadline Repository and Nebula lighthouse on a cloud server 
# =======================================================================
# Challenge/answer script to modify a Alma/Rocky 8.x Linux virtual machine
# - The increased security of firewalld, SElinux WILL be the cause of the
#   majority of things not connecting but this risk to ease of use reduces
#   the attack vector surface of services liek Samba and MongoDB. This is
#   especially critical since MongoDB is the jobber to the renderfarm and
#   infiltration of this server means any job can be sent to the render nodes.

if ! [[ "$OSTYPE" == "linux-gnu"* ]]; then
	echo -e "FAIL: This can only be installed on Alma or Rocky Linux 8.x"
	exit
fi
thinkboxurl="https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/2_10.3.0.10/"
thinkboxtar="Deadline-10.3.0.10-linux-installers.tar"
thinkboxrun="./DeadlineRepository-10.3.0.10-linux-x64-installer.run"
mongourl="https://fastdl.mongodb.org/linux/"
mongotar="mongodb-linux-x86_64-rhel80-4.4.16.tgz"
keybundle_url_default="https://drive.google.com/file/d/1a98gFtDRyF_Bs3MkgoAvxOoMio3RDCN6/view?usp=share_link"

nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"
#nebulasha256="20d363a917f802dff3db13471b38d4f29c0bef6728f0808ce0f766f073ef3927"
echo -e "\n==================================================================="
echo -e "Bootstrap Linux machine into DeadlineRepository + Nebula lighthouse"
echo -e "Warning: Major changes are forthcoming"
echo -e "DO NOT run this machine on a production machine"
echo -e " - Deploy Deadline Repository to /mnt/DeadlineRepository10"
echo -e " - create deadline,mongodb users"
echo -e " - install/start Samba file server"
echo -e " - install/start MongoDB 4.4.16 with nossl"
echo -e " - establish Nebula overlay 10.10.0.0/16 private network aka VPN"
echo -e " - install/enable firewalld, create nebula zone, remove services"
echo -e " - enable Selinux, change context Nebula and Samba share"
echo -e " - Only runs on Alma/Rocky 8.x Linux"
echo -e " - You agree to the AWS Thinkbox EULA by installing Deadline"
echo -e "==================================================================="
echo -e "Continue on $(hostname)?"
read -p "    (Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
	echo -e "\nScript aborted because Yes was not entered"
	exit
fi


dnf -y install tar

# Use AWS service to get public ip
public_ip=$(curl -s https://checkip.amazonaws.com)
echo -e "\nCalculated IPv4 address: $public_ip"

nebula_name_default="i_agree_this_is_unsafe"
echo -e "\n\tTEST WAY: Using \"${nebula_name_default}\" keybundle is insecure because it is a public set of keys with a knowable passphrase in this source code, by using these keys you acknowledge that anybody else with these same keys can enter your Nebula network. It provides a modicum of security because they would also have to know that your server is at ${public_ip}"
echo -e "This methods allows rapid deployment to kick the tires and use 100% defaults and 98% fewer challenge questions compared to the \"CORRECT WAY\""
echo -e "\n\tCORRECT WAY: Generate keys on a trusted computer using keyfarmfarm.sh where you personally authorize each and every machine on your network and you control the certificate-authority. Store the encrypted files on Google Drive, shared with \"Anyone with the Link\", hit \"copy link\" button, type \"hub\" below unless you didn't use the keyoomerfarm.sh defaults"
echo -e "\nENTER Nebula Lighthouse hub name"
read -p "    (default: $nebula_name_default:) " nebula_name
if [ -z "$nebula_name" ]; then
	nebula_name=$nebula_name_default
fi

# probe to see if downloadables exist
if ! ( curl -s --head --fail -o /dev/null ${thinkboxurl}${thinkboxtar} ); then
	echo -e "FAIL: No file found at ${mongourl}${mongotar}"
	exit
fi
if ! ( curl -s --head --fail -o /dev/null ${mongourl}${mongotar} ); then
	echo -e "FAIL: No file found at ${mongourl}${mongotar}"
	exit
fi

encryption_passphrase="oomerfarm"	
linux_password="oomerfarm"	
nebula_ip="10.10.0.1"
nebula_ip_default="10.10.0.1"
nebula_public_port="42042"
nebula_public_port_default="42042"
nebula_version="v1.7.2"
nebula_version_default="v1.7.2"
groupname_nottrusted="oomerfarm"
groupname_nottrusted_default="oomerfarm"
groupname_trusted="oomerfarm-admin"
groupname_trusted_default="oomerfarm-admin"
smb_user="oomerfarm"
smb_user_default="oomerfarm"

if ! [ "$nebula_name" = "i_agree_this_is_unsafe" ]; then
	echo -e "\nENTER Nebula encryption passphrase to decrypt keys"
	echo "Keystrokes hidden, then hit return"
	echo "..."
	IFS= read -rs encryption_passphrase < /dev/tty
	if [ -z "$encryption_passphrase" ]; then
		echo -e "\nFAIL: Invalid empty passphrase"
		exit
	fi

	echo -e "\nENTER Nebula private IP address IPV4"
	echo -e "Customize Nebula network addresses using keyoomerfarm.sh"
	read -p "    (default: $nebula_ip_default): " nebula_ip
	if [ -z "$nebula_ip" ]; then
	    nebula_ip=$nebula_ip_default
	fi

	echo -e "\nEnter Nebula internet port"
	read -p "    (default: $nebula_public_port_default): " nebula_public_port
	if [ -z "$nebula_public_port" ]; then
	    nebula_public_port=$nebula_public_port_default
	fi

	echo -e "\nENTER Nebula version"
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

	echo -e "\nWhat username would you like to connect to the fil server?"
	read -p "    (default: $smb_user_default): " deadline_user
	if [ -z "$smb_user" ]; then
	    smb_user=$deadline_user_default
	fi

	echo -e "\nENTER Google Drive URL to your keybundle"
	read -p "    (default: $keybundle_url_default): " keybundle_url
	if [ -z "$keybundle_url" ]; then
	    keybundle_url=$keybundle_url_default
	fi



	if ! [ "$nebula_name" = "I_agree_this_is_unsafe_hub" ]; then
		echo -e "\nEnter Linux/smb password of deadline user"
		echo "Keystrokes hidden, then hit return"
		echo "===="
		IFS= read -rs linux_password < /dev/tty
		if [ -z "$linux_password" ]; then
		    echo -e "\nFAIL: invalid empty password"
		    exit
		fi
	fi
else
	keybundle_url=$keybundle_url_default
fi

# Ensure max security
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

# May be bad for ntp
chronyd_status=$( systemctl status chronyd )
if [[ "$chronyd_status" == *"Active: active (running)"* ]]; then
	systemctl stop chronyd
	systemctl disable chronyd
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

test_user=$( id "${smb_user}" )
# id will return blank if no user is found
if [ -z "$test_user" ]; then
	echo "CREATE USER:${smb_user}"
        useradd -m ${smb_user}
fi
echo "${smb_user}:${linux_password}" | chpasswd

# Install Nebula
# ==============
if ! ( test -d /etc/nebula ); then
	mkdir -p /etc/nebula
fi 
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


echo "$keybundle_url"

# Get Nebula credentials
# ======================



if [[ "$keybundle_url" == *"https://drive.google.com/file/d"* ]]; then
	# if find content-length, then gdrive link is not restricted, this is a guess
	head=$(curl -s --head ${keybundle_url} | grep "content-length")
	if [[ "$head" == *"content-length"* ]]; then
		# Extract Google uuid 
		googlefileid=$(echo $keybundle_url | egrep -o '(\w|-){26,}')
		head2=$(curl -s --head -L "https://drive.google.com/uc?export=download&id=${googlefileid}" | grep "content-length")
		if [[ "$head2" == *"content-length"* ]]; then
			echo "Downloading https://drive.google.com/uc?export=download&id=${googlefileid}"
			curl -L "https://drive.google.com/uc?export=download&id=${googlefileid}" -o ${nebula_name}.keybundle.enc
		else
			echo "FAIL: ${keybundle_url} is not public, Set General Access to Anyone with Link"
			exit
		fi
	else
		echo "FAIL: ${keybundle_url} is not a valid Google Drive link"
		exit
	fi
else
	curl -s -L -O "${keybundle_url}${nebula_name}.keybundle.enc" 
fi

while :
do
    if openssl enc -aes-256-cbc -pbkdf2 -d -in ${nebula_name}.keybundle.enc -out ${nebula_name}.keybundle -pass file:<( echo -n "$encryption_passphrase" ) ; then
        break
    else
        echo "WRONG passphrase entered for ${nebula_name}.keybundle.enc, try again"
        echo "Enter passphrase for ${nebula_name}.keybundle.enc, then hit return"
        echo "==============================================================="
        IFS= read -rs $encryption_passphrase < /dev/tty
    fi 
done  




# extract credentials
# =================== 

testkeybundle=$( tar -tf ${nebula_name}.keybundle ./${nebula_name}/${nebula_name}.key 2>&1 )
echo $testkeybundle
if ! [[ "${testkeybundle}" == *"Not found"* ]]; then
	#cpio --warning=none -i --to-stdout "./${nebula_name}/ca.crt" < ${nebula_name}.tar > ca.crt
	#cpio --warning=none -i --to-stdout "./${nebula_name}/${nebula_name}.crt" < ${nebula_name}.tar > ${nebula_name}.crt
	#cpio --warning=none -i --to-stdout "./${nebula_name}/${nebula_name}.key" < ${nebula_name}.tar > ${nebula_name}.key
	tar --to-stdout -xvf ${nebula_name}.keybundle ./${nebula_name}/ca.crt > ca.crt
	tar --to-stdout -xvf ${nebula_name}.keybundle ./${nebula_name}/${nebula_name}.crt > ${nebula_name}.crt
	ERROR=$( tar --to-stdout -xvf ${nebula_name}.keybundle ./${nebula_name}/${nebula_name}.key > ${nebula_name}.key 2>&1 )
	# [TODO] empty file created on cpio error, test fails
	if ! [ "$ERROR" == *"Fail"* ]; then
	    chown root.root "${nebula_name}.key"
	    chown root.root "${nebula_name}.crt"
	    chown root.root "ca.crt"
	    chmod go-rwx "${nebula_name}.key"
	    mv ca.crt /etc/nebula
	    mv "${nebula_name}.crt" /etc/nebula
	    mv "${nebula_name}.key" /etc/nebula
	    #rm ${nebula_name}.keybundle
	    #rm ${nebula_name}.keybundle.enc
	fi 
else
        echo -e "=========="
        echo -e "FAIL: ${nebula_name}.key missing"
	echo  "${keybundle_url} might be corrupted or not shared publicly"
	echo  "Use keyoomerfarm.sh to generate correct name in credential, reupload"
	echo  "Check your Google Drive file link is \"Anyone who has link\""
	exit
fi

# Default port 4242 but chose port 42042 to avoid collision
firewall-cmd -q --zone=public --add-port=${nebula_public_port}/udp --permanent
firewall-cmd -q --reload

cat <<EOF > /etc/nebula/config.yml
# Lighthouse config.yml supporting Samba server and MongoDB

pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/${nebula_name}.crt
  key: /etc/nebula/${nebula_name}.key

static_host_map:
  "${nebula_ip}": ["${public_ip}:${nebula_public_port}"]

lighthouse:
  am_lighthouse: true
  interval: 60

listen:
  host: 0.0.0.0
  port: ${nebula_public_port}

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

    - port: 445
      proto: tcp
      groups:
        - oomerfarm

    - port: 27100
      proto: tcp
      groups:
        - oomerfarm
EOF

cat <<EOF > /etc/systemd/system/nebula.service
[Unit]
Description=Nebula Launcher Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=30
ExecStart=/usr/local/bin/nebula -config /etc/nebula/config.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now nebula


# Install Samba
# =============
echo -e "\nInstalling Samba"
dnf -yq install cifs-utils
dnf -yq install kernel-modules
dnf -yq install samba

cat <<EOF > /etc/samba/smb.conf
ntlm auth = mschapv2-and-ntlmv2-only
interfaces = 127.0.0.1 ${nebula_ip}/16
bind interfaces only = yes
disable netbios = yes
smb ports = 445

[DeadlineRepository10]
   path = /mnt/DeadlineRepository10
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0777
   directory mask = 0777

[oomerfarm]
   path = /mnt/oomerfarm
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0777
   directory mask = 0777
EOF


systemctl enable --now smb

# Create nebula firewalld zone attached to Nebula interface "nebula_tun"
firewall-cmd -q --new-zone nebula --permanent
firewall-cmd -q --zone nebula --add-interface nebula_tun --permanent
firewall-cmd -q --zone nebula --add-service ssh --permanent
firewall-cmd -q --zone nebula --add-port 445/tcp --permanent
firewall-cmd -q --zone nebula --add-port 27100/tcp --permanent
firewall-cmd -q --reload
if ! ( test -d /mnt/DeadlineRepository10 ); then
	mkdir -p /mnt/DeadlineRepository10
	mkdir -p /mnt/oomerfarm
	mkdir -p /mnt/oomerfarm/bella
	mkdir -p /mnt/oomerfarm/bella/renders
	chown oomerfarm.oomerfarm /mnt/oomerfarm
	chown oomerfarm.oomerfarm /mnt/oomerfarm/bella
	chown oomerfarm.oomerfarm /mnt/oomerfarm/bella/renders
	chcon -R -t samba_share_t /mnt/DeadlineRepository10/
	chcon -R -t samba_share_t /mnt/oomerfarm/
fi



# Set password, confirm password
(echo ${linux_password}; echo ${linux_password}) | smbpasswd -a oomerfarm -s

# Install MongoDB
# ===============

if ! test -d /opt/Thinkbox/DeadlineDatabase10/mongo/application/mongodb-linux-x86_64-rhel80-4.4.16 ; then
	echo -e "\nInstalling MongoDB"
	echo -e "=================="
	test_group=$( getent group mongod )
	if [ -z "${test_group}" ]; then
		echo "CREATE GROUP: mongod"
		groupadd -g 3001 mongod
	fi

	test_user=$( id mongod )
	# id will return blank if no user is found
	if [ -z "${test_user}" ]; then
		echo "CREATE USER: mongod"
		useradd -g 3001 -u 3001 -r mongod
	fi

	if ! ( test -d /opt/Thinkbox/DeadlineDatabase10/mongo ); then
		mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo
	fi
	if ! ( test -d /opt/Thinkbox/DeadlineDatabase10/mongo/log ); then
		mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/log
	fi 
	chown mongod.mongod /opt/Thinkbox/DeadlineDatabase10/mongo
	chown mongod.mongod /opt/Thinkbox/DeadlineDatabase10/mongo/log
	orig_dir=$(pwd)
	cd /opt/Thinkbox/DeadlineDatabase10/mongo
	if ! ( test -d application/mongodb-linux-x86_64-rhel80-4.4.16 ); then
		echo -e "Downloading ${mongourl}${mongotar}"
		curl -s -O ${mongourl}${mongotar}
		tar --skip-old-files -xf ${mongotar}
		mv mongodb-linux-x86_64-rhel80-4.4.16 application
		rm ${mongotar}
	fi

#Assumes Deadline version 10
cat <<EOF > /etc/systemd/system/mongod.service
[Unit]
Description=Mongod Launcher Service
After=network.target
Requires=nebula.service

[Service]
Type=simple
Restart=always
RestartSec=35
User=mongod
Group=mongod
Environment="OPTIONS=-f /opt/Thinkbox/DeadlineDatabase10/mongo/mongod.conf"
ExecStart=/opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod \$OPTIONS
ExecStartPre=/usr/bin/mkdir -p /var/run/mongodb /var/lib/mongo
ExecStartPre=/usr/bin/chown mongod:mongod /var/run/mongodb /var/lib/mongo
ExecStartPre=/usr/bin/chmod 0755 /var/run/mongodb
ExecStartPre=/usr/bin/chmod 0700 /var/lib/mongo
PermissionsStartOnly=true
PIDFile=/var/run/mongodb/mongod.pid

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /opt/Thinkbox/DeadlineDatabase10/mongo/mongod.conf
net:
  bindIp: ${nebula_ip} 
  port: 27100
  ipv6: false
  ssl:
    mode: disabled

storage:
  # Database files will be stored here
  dbPath: /opt/Thinkbox/DeadlineDatabase10/mongo/
  engine: wiredTiger

systemLog:
  destination: file
  path: /opt/Thinkbox/DeadlineDatabase10/mongo/log/mongod.log

security:
  authorization: disabled
EOF

	systemctl enable --now mongod.service
else
	echo -e "MongoDB already installed...installation skipped"
fi
# Get Thinkbox software
# =====================
echo -e "\nInstalling Deadline Renderfarm Software"
echo -e "========================================"
if ! test -f /mnt/DeadlineRepository10/ThinkboxEULA.txt ; then
	echo -e "\nChecking existence of ${thinkboxurl}${thinkboxtar}" 
	if ! (curl -s --head --fail -o /dev/null "${thinkboxurl}${thinkboxtar}" ); then
		echo -e "FAIL: no Thinkbox Software at ${thinkboxurl}${thinkboxtar}"
		exit
	fi

	cd ${orig_dir}
	if ! ( test -f "${thinkboxtar}" ); then
		echo -e "\nDownloading AWS Thinkbox Deadline Software 900MB+ ..."
		curl -sL -O ${thinkboxurl}${thinkboxtar}
	fi
	MatchFile="$(echo "2da400837c202b2e0b306d606c3f832e4eae91822e2ac98f7ab6db241af77a43 ${thinkboxtar}" | sha256sum --check)"
	if [ "$MatchFile" == "${thinkboxtar}: OK" ] ; then
	    echo -e "Extracting ${thinkboxurl}${thinkboxtar}\n===="
	    tar --skip-old-files -xzf ${thinkboxtar}
	else
	    echo "FAIL: ${thinkboxtar} checksum failed, file possibly maliciously altered on AWS"
	    exit
	fi
	rm DeadlineClient-10.3.0.10-linux-x64-installer.run
	rm DeadlineClient-10.3.0.10-linux-x64-installer.run.sig
	rm DeadlineRepository-10.3.0.10-linux-x64-installer.run.sig
	rm AWSPortalLink-1.3.0.3-linux-x64-installer.run
	rm AWSPortalLink-1.3.0.3-linux-x64-installer.run.sig

	echo ${thinkboxrun} --mode unattended --unattendedmodeui none --prefix /mnt/DeadlineRepository10 --dbLicenseAcceptance accept --dbhost ${nebula_ip}
	${thinkboxrun} --mode unattended --unattendedmodeui none --prefix /mnt/DeadlineRepository10 --dbLicenseAcceptance accept --dbhost ${nebula_ip}
	echo -e "\n\nYou accept AWS Thinkbox Deadline EULA when installing:"
	echo -e "========================================================"
	cat /mnt/DeadlineRepository10/ThinkboxEULA.txt
else
	echo "Deadline Repository exists...skipping installation"
fi

mkdir /mnt/DeadlineRepository10/custom/plugins/BellaRender
mkdir /mnt/DeadlineRepository10/custom/scripts/Submission
cp DeadlineRepository10/custom/plugins/BellaRender/BellaRender.param /mnt/DeadlineRepository10/custom/plugins/BellaRender/BellaRender.param
cp DeadlineRepository10/custom/plugins/BellaRender/BellaRender.py /mnt/DeadlineRepository10/custom/plugins/BellaRender/BellaRender.py
cp cp DeadlineRepository10/custom/plugins/BellaRender/bella.ico /mnt/cp DeadlineRepository10/custom/plugins/BellaRender/bella.ico
cp DeadlineRepository10/custom/scripts/Submission/BellaRender.py /mnt/DeadlineRepository10/custom/scripts/Submission/BellaRender.py




# [TODO] switch to ssl for better security
sed -i "s/Authenticate=.*/Authenticate=False/g" /mnt/DeadlineRepository10/settings/connection.ini

curl -O https://downloads.bellarender.com/bella_cli-23.4.0.tar.gz
MatchFile="$(echo "afb15d150fc086709cc726c052dd40cd115eb8b32060c7a82bdba4f6d9cebd3d bella_cli-23.4.0.tar.gz" | sha256sum --check)"
if [ "$MatchFile" = "bella_cli-23.4.0.tar.gz: OK" ] ; then
	mv bella_cli-23.4.0.tar.gz /mnt/oomerfarm/installers/bella_cli-23.4.0.tar.gz
else
	rm bella_cli-23.4.0.tar.gz 
	echo "FAIL: bella checksum failed, may be corrupted or malware"
fi
curl -L https://bellarender.com/doc/scenes/orange-juice/orange-juice.bsz -o /mnt/oomerfarm/bella/orange-juice.bsz
chown oomerfarm.oomerfarm /mnt/oomerfarm/bella/orange-juice.bsz

afb15d150fc086709cc726c052dd40cd115eb8b32060c7a82bdba4f6d9cebd3d  /mnt/oomerfarm/installers/bella_cli-23.4.0.tar.gz


if [ "$nebula_name" == "i_agree_this_is_unsafe" ]; then
	echo -e "\n==================================================================="
	echo -e "The Nebula Lighthouse and Deadline Repository succesfully installed"
	echo -e "The oomerfarm hub is ready to accept job submissions"
	echo -e "Write down ${public_ip} ( internet ip address of this Lighthouse )"
	echo -e "feed this address into joinoomerfarm.sh"
	echo -e "Submit a job from a Windows/MacOS/Linux desktop by installing"
	echo -e "https://www.awsthinkbox.com"
	echo -e "==================================================================="
	echo -e "\n************************************************************"
	echo -ne "By choosing the \"${nebula_name}\" keybundle, you acknowledge that anybody can"
	echo -ne " connect to this machine via ${public_ip} on port ${nebula_public_port} because"
	echo -ne " the decryption passphrase is in this script. This creates a modicum of security"
	echo -ne " by obscurity requiring knowledge of ${public_ip}." 
	echo -e " Only use the \"${nebula_name}\" keybundle for testing purposes."
	echo 
	echo -ne " Significantly augment security by creating a certificate-authority allowing"
	echo -ne " the signing of custom certificates and keys"
	echo 
	echo -ne " Run keyoomerfarm.sh on a TRUSTED COMPUTER to learn how" 
	echo -ne " then come back and rerun this script on $(hostname) at ${public_ip}"
	echo -e " using your own keybundle NOT \"${nebula_name}\""
	echo -e "************************************************************"
else
	echo -e "\n==================================================================="
	echo -e "The Nebula Lighthouse and Deadline Repository succesfully installed"
	echo -e "The oomerfarm hub is ready to accept job submissions"
	echo -e "Submit a job from a Windows/MacOS/Linux desktop by installing"
	echo -e "https://www.awsthinkbox.com"
	echo -e "==================================================================="
fi
