#!/bin/bash

# bootstraphub.sh

# Turns this machine into a renderfarm hub
# ========================================

encryption_passphrase="oomerfarm"	
nebula_ip_default="10.87.0.1"
nebula_ip=$nebula_ip_default
nebula_public_port_default="42042"
nebula_public_port=$nebula_public_port_default
nebula_version_default="v1.7.2"
nebula_version=$nebula_version_default
smb_user_default="oomerfarm"
smb_user=$smb_user_default
linux_password="oomerfarm"	

if ! [[ "$OSTYPE" == "linux-gnu"* ]]; then
	echo -e "\e[31mFAIL:\e[0m This can only be installed on \e[5mAlma or Rocky Linux 8.x\e[0m"
	exit
fi

skip_advanced="yes"
skip_advanced_default="yes"

# deadline
# ======== 
thinkboxversion="10.3.0.15"
thinkboxurl="https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/4_${thinkboxversion}/"
thinkboxtar="Deadline-${thinkboxversion}-linux-installers.tar"
thinkboxsha256="6ada6b2fc222974ae5a64101a01ae9d5ab7a297e8f131b22d8512eb767d3e9be"
thinkboxrun="./DeadlineRepository-${thinkboxversion}-linux-x64-installer.run"

# s3 fuse filesystem
# ==================
goofysurl="https://github.com/kahing/goofys/releases/download/v0.24.0/goofys"
goofyssha256="729688b6bc283653ea70f1b2b6406409ec1460065161c680f3b98b185d4bf364"

# bella
# =====
bella_version="23.4.0"
bellasha256="afb15d150fc086709cc726c052dd40cd115eb8b32060c7a82bdba4f6d9cebd3d"

# mongodb
# =======
mongourl="https://fastdl.mongodb.org/linux/"
mongotar="mongodb-linux-x86_64-rhel80-4.4.16.tgz"
mongosha256="78c3283bd570c7c88ac466aa6cc6e93486e061c28a37790e0eebf722ae19a0cb"

# no-so-secret i_agree_this_is_unsafe.keys.encrypted
# ==================================================
keybundle_url_default="https://drive.google.com/file/d/1uiVSKuzhJ64mlsK0t4xMFYBX2IkQLB0b/view?usp=sharing"
nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"

# Use AWS service to get public ip
public_ip=$(curl -s https://checkip.amazonaws.com)

echo -e "\n\e[32mTurns this machine into a renderfarm\e[0m \e[36m\e[5mhub\e[0m\e[0m"
echo -e "\e[31mWARNING:\e[0m Security changes will break any existing server"
echo -e " - become VPN node at \e[36m${nebula_ip}/16\e[0m"
echo -e " - deploy VPN lighthouse at \e[36m${public_ip}\e[0m for internet-wide network"
echo -e " - deploy VPN file server, at \e[36msmb://hub.oomer.org\e[0m, \e[36m//hub.oomer.org\e[0m (win)"
echo -e " - install MongoDB 4.4.16 \e[37m/opt/Thinkbox/DeadlineDatabase10\e[0m"
echo -e " - install Deadline Repository \e[37m/mnt/DeadlineRepository10\e[0m"
echo -e " - install Deadline Client \e[37m/opt/Thinkbox/Deadline10\e[0m"
echo -e " - run License Forwarder for \e[37mUsage Based Licensing\e[0m"
echo -e " - \e[37mfirewall\e[0m blocks ALL non-oomerfarm ports"
echo -e " - enforce \e[37mselinux\e[0m for maximal security"
echo -e " - Only runs on RHEL/Alma/Rocky 8.x Linux"
echo -e " - You agree to the \e[37mAWS Thinkbox EULA\e[0m by installing Deadline"
echo -e " - Optionally mounts \e[37m/mnt/s3\e[0m"
echo -e " - Optionally installs \e[37mHoudini\e[0m"
echo -e "\e[32mContinue on\e[0m \e[37m$(hostname)?\e[0m"

read -p "(Enter Yes) " accept
if [ "$accept" != "Yes" ]; then
        echo -e "\n\e[31mFAIL:\e[0m Script aborted because Yes was not entered"
        exit
fi

nebula_name_default="i_agree_this_is_unsafe"

echo -e "\n\e[32mSecure Method:\e[0m On a trusted computer, generate secret keys ( not this computer ) using \e[36mkeyoomerfarm.sh\e[0m BEFORE running this script. Type \e[36mhub\e[0m below for the secure method"

echo -e "\n\e[32mTest Drive:\e[0m \e[36m${nebula_name_default}\e[0m are not-so-secret keys securing oomerfarm with a VPN. Since they allow intrusion without your knowledge only use them to test oomerfarm. Analogy: house keys can be lost and your locks continue to work, BUT a stranger who finds your keys AND knows where you live can easily enter. Hit enter below to use \e[36mi_agree_this_is_unsafe\e[0m with security by obscurity"

echo -e "\nENTER \e[36m\e[5mhub\e[0m\e[0m or \e[36m\e[5m${nebula_name_default}\e[0m\e[0m"
read -p "(default: $nebula_name_default:) " nebula_name
if [ -z "$nebula_name" ]; then
	nebula_name=$nebula_name_default
fi

# probe to see if downloadable depenencies exist
# ==============================================
if ! ( curl -s --head --fail -o /dev/null ${thinkboxurl}${thinkboxtar} ); then
	echo -e "\e[31mFAIL:\e[0m No file found at ${thinkboxurl}${thinkboxtar}"
	echo -e "Usually means Amazon has releases a new version"
	echo -e "and removed the old link"
	echo -e "This script needs updating but until then you can"
	echo -e "Go to https://awsthinkbox.com -> Downloads ->"
	echo -e "Choose Deadline Linux"
	exit
fi

if ! ( curl -s --head --fail -o /dev/null ${mongourl}${mongotar} ); then
	echo -e "FAIL: No file found at ${mongourl}${mongotar}"
	exit
fi

if ! [ "$nebula_name" = "i_agree_this_is_unsafe" ]; then
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

	echo -e "\nENTER \e[36m\e[5mpassphrase\e[0m\e[0m to decode \e[32mhub.keys.encrypted\e[0m YOU set in \"keyauthority.sh\"  ( keystrokes hidden )"
	IFS= read -rs encryption_passphrase < /dev/tty
	if [ -z "$encryption_passphrase" ]; then
		echo -e "\n\e[31mFAIL:\e[0m Invalid empty passphrase"
		exit
	fi

	echo -e "\n\e[36m\e[5mURL\e[0m\e[0m to \e[32mhub.keys.encrypted\e[0m"
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

		echo -e "\n\e[36m\e[5mSet password\e[0m\e[0m to access hub file server ( keystrokes hidden )"
		IFS= read -rs linux_password < /dev/tty
		if [ -z "$linux_password" ]; then
		    echo -e "\n\e[31mFAIL:\e[0m invalid empty password"
		    exit
		fi

		echo -e "\nSet VPN \e[36m\e[5mIP address\e[0m\e[0m"
		read -p "(default: $nebula_ip_default): " nebula_ip
		if [ -z "$nebula_ip" ]; then
		    nebula_ip=$nebula_ip_default
		fi

		echo -e "\nSet VPN public \e[36m\e[5mudp port\e[0m\e[0m"
		read -p "(default: $nebula_public_port_default): " nebula_public_port
		if [ -z "$nebula_public_port" ]; then
		    nebula_public_port=$nebula_public_port_default
		fi

		echo -e "\nSet \e[36m\e[5musername\e[0m\e[0m"
		read -p "(default: $smb_user_default): " deadline_user
		if [ -z "$smb_user" ]; then
		    smb_user=$deadline_user_default
		fi
		dnf -y install fuse

	fi

else
	keybundle_url=$keybundle_url_default
fi

dnf -y install tar

# Ensure max security
# ===================

# disallow ssh password authentication
sed -i -E 's/#?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config 

# enable firewalld
firewalld_status=$(systemctl status firewalld)

if [ -z "$firewalld_status" ]; then
	echo -e "\e[32mInstalling firewalld...\e[0m"
	dnf -y install firewalld
	systemctl enable --now firewalld
fi

if ! [[ "$firewalld_status" == *"running"* ]]; then
	systemctl enable --now firewalld
fi

test_user=$( id "${smb_user}" )
# id will return blank if no user is found
if [ -z "$test_user" ]; then
	echo -e "\e[32mCreating user:\e[0m ${smb_user}"
	groupadd -g 3000 ${smb_user}
        useradd -g 3000 -u 3000 -m ${smb_user}
fi
echo "${smb_user}:${linux_password}" | chpasswd

# Install Nebula
# ==============

mkdir -p /etc/nebula
mkdir -p /etc/deadline
echo -e "\e[32mDownloading Nebula VPN\e[0m"
curl -L -O https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz
MatchFile="$(echo "${nebulasha256} nebula-linux-amd64.tar.gz" | sha256sum --check)"
if [ "$MatchFile" = "nebula-linux-amd64.tar.gz: OK" ] ; then
    echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/nebula-linux-amd64.tar.gz\n"
    tar --skip-old-files -xzf nebula-linux-amd64.tar.gz
else
    echo -e "\e[31mFAIL:\e[0m nebula-linux-amd64.tar.gz checksum failed, file possibly maliciously altered on github"
    exit
fi
mv nebula /usr/local/bin/nebula
chmod +x /usr/local/bin/
mv nebula-cert /usr/local/bin/
chmod +x /usr/local/bin/nebula-cert
chcon -t bin_t /usr/local/bin/nebula # SELinux security clearance
rm -f nebula-linux-amd64.tar.gz

# Install goofys needed for Houdini and UBL
if ! [[ $skip_advanced == "yes" ]]; then
	if ! ( test -f /usr/local/bin/goofys ); then
		curl -L -o /usr/local/bin/goofys https://github.com/kahing/goofys/releases/download/v0.24.0/goofys
		MatchFile="$(echo "${goofyssha256} /usr/local/bin/goofys" | sha256sum --check)"
		if [ "$MatchFile" = "/usr/local/bin/goofys: OK" ] ; then
			chmod +x /usr/local/bin/goofys
			mkdir -p /mnt/s3
			chown root.root /usr/local/bin/goofys
			chcon -t bin_t /usr/local/bin/goofys # SELinux security clearance
		else
			echo "FAIL"
			echo "goofys checksum is wrong, may indicate download failure of malicious alteration"
			exit
		fi
	fi

        grep -qxF "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" /etc/fstab || echo "goofys#oomerfarm /mnt/s3 fuse ro,_netdev,allow_other,--file-mode=0666,--dir-mode=0777,--endpoint=$s3_endpoint 0 0" >> /etc/fstab
        systemctl daemon-reload
        mkdir -p /mnt/s3
        mount /mnt/s3
	mkdir -p /etc/deadline
	cp -n /mnt/s3/houdini/mantra.pfx /etc/deadline
	cp -n /mnt/s3/houdini/houdini.pfx /etc/deadline
fi


# Get keys.encrypted from public url
# =====================================

# Google drive links require complicated traveral
# Google cannot direct share large files or else this would be abused
if [[ "$keybundle_url" == *"https://drive.google.com/file/d"* ]]; then
	# if find content-length, then gdrive link is not restricted, this is a guess
	head=$(curl -s --head ${keybundle_url} | grep "content-length")
	if [[ "$head" == *"content-length"* ]]; then
		# Extract Google uuid 
		googlefileid=$(echo $keybundle_url | egrep -o '(\w|-){26,}')
		head2=$(curl -s --head -L "https://drive.google.com/uc?export=download&id=${googlefileid}" | grep "content-length")
		if [[ "$head2" == *"content-length"* ]]; then
			echo -e "\e[32mDownloading secret keys https://drive.google.com/uc?export=download&id=${googlefileid}\e[0m"
			curl -L "https://drive.google.com/uc?export=download&id=${googlefileid}" -o ${nebula_name}.keys.encrypted
		else
			echo -e "\e[31mFAIL:\e[0m ${keybundle_url} is not public, Set General Access to Anyone with Link"
			exit
		fi
	else
		echo -e "\e[31mFAIL:\e[0m ${keybundle_url} is not a valid Google Drive link"
		exit
	fi
# This should work with URL's pointing to normal website locations or public S3 storage 
else
	curl -L "${keybundle_url}"  -o ${nebula_name}.keys.encrypted
	if ! ( test -f ${nebula_name}.keys.encrypted ) ; then
		echo -e "\e[31mFAIL:\e[0m ${nebula_name}.keys.encrypted URL you entered \e[31m${keybundle_url}\e[0m does not exist"
		exit
	fi
fi

# decrypt keys.encrypted
# ======================
while :
do
    if openssl enc -aes-256-cbc -pbkdf2 -d -in ${nebula_name}.keys.encrypted -out ${nebula_name}.tar -pass file:<( echo -n "$encryption_passphrase" ) ; then
	rm ${nebula_name}.keys.encrypted
        break
    else
        echo "WRONG passphrase entered for ${nebula_name}.keys.encrypted, try again"
        echo "Enter passphrase for ${nebula_name}.keys.encrypted, then hit return"
        echo "==============================================================="
        IFS= read -rs $encryption_passphrase < /dev/tty
    fi 
done  

testkeybundle=$( tar -tf ${nebula_name}.tar ${nebula_name}/${nebula_name}.key 2>&1 )
if ! [[ "${testkeybundle}" == *"Not found"* ]]; then
	tar --to-stdout -xvf ${nebula_name}.tar ${nebula_name}/ca.crt > ca.crt
	tar --to-stdout -xvf ${nebula_name}.tar ${nebula_name}/${nebula_name}.crt > ${nebula_name}.crt
	ERROR=$( tar --to-stdout -xvf ${nebula_name}.tar ${nebula_name}/${nebula_name}.key > ${nebula_name}.key 2>&1 )
	if ! [ "$ERROR" == *"Fail"* ]; then
	    chown root.root "${nebula_name}.key"
	    chown root.root "${nebula_name}.crt"
	    chown root.root "ca.crt"
	    chmod go-rwx "${nebula_name}.key"
	    mv ca.crt /etc/nebula
	    mv "${nebula_name}.crt" /etc/nebula
	    mv "${nebula_name}.key" /etc/nebula
	    rm ${nebula_name}.tar
	else
	    rm ${nebula_name}.tar
	fi 
else
        echo -e "\e[31mFAIL:\e[0m ${nebula_name}.keys.encrypted missing"
	echo  "${keybundle_url} might be corrupted or not shared publicly"
	echo  "Use keyauthority.sh to generate keys, reupload"
	echo  "Check your Google Drive file link is \"Anyone who has link\""
	exit
fi

# create Nebula config file
# =========================
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
        - oomer
        - person

    - port: 445
      proto: tcp
      groups:
        - oomer

    - port: 27100
      proto: tcp
      groups:
        - oomer

    - port: 17004
      proto: tcp
      groups:
        - oomer

    - port: 1714
      proto: tcp
      groups:
        - oomer

    - port: 1715
      proto: tcp
      groups:
        - oomer

    - port: 1716
      proto: tcp
      groups:
        - oomer

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
echo -e "\n\e[32mInstalling File Server ( Samba )...\e[0m"
dnf -y install cifs-utils
dnf -y install kernel-modules
dnf -y install samba

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

# ***FIREWALL rules***
# adopting highly restrictive rules to protect network
echo -e "\n\e[32mTurning up Firewall security...\e[0m"

# Wipe all services and ports except ssh and 22/tcp, may break system
for systemdservice in $(firewall-cmd --list-services --zone public);
do 
	if ! [[ "$systemdservice" == "ssh" ]]; then
		firewall-cmd -q --zone public --remove-service ${systemdservice} --permanent
	fi
done
for systemdport in $(firewall-cmd --list-ports --zone public);
do 
	if ! [[ "$systemdport" == "22/tcp" ]]; then
		firewall-cmd -q --zone public --remove-port ${systemdport} --permanent
	fi
done
firewall-cmd -q --reload


# Allow Nebula VPN connections over internet
firewall-cmd -q --zone=public --add-port=${nebula_public_port}/udp --permanent

# Add Nebula zone on "nebula_tun"
firewall-cmd -q --new-zone nebula --permanent
firewall-cmd -q --zone nebula --add-interface nebula_tun --permanent

# Allow ssh connections over VPN
firewall-cmd -q --zone nebula --add-service ssh --permanent

# Allow smb/cifs connections over VPN
firewall-cmd -q --zone nebula --add-port 445/tcp --permanent

# Allow MongoDB connections over VPN
firewall-cmd -q --zone nebula --add-port 27100/tcp --permanent

# deadline license forwarder for Usage Based Licensing
firewall-cmd -q --zone nebula --add-port 17004/tcp --permanent
firewall-cmd -q --zone nebula --add-port 40645/tcp --permanent

# houdini UBL passthrough
firewall-cmd -q --zone nebula --add-port 1714/tcp --permanent
firewall-cmd -q --zone nebula --add-port 1715/tcp --permanent
firewall-cmd -q --zone nebula --add-port 1716/tcp --permanent

firewall-cmd -q --reload

# Prep Deadline Repo
if ! ( test -d /mnt/DeadlineRepository10 ); then
	mkdir -p /mnt/DeadlineRepository10
	mkdir -p /mnt/oomerfarm
	mkdir -p /mnt/oomerfarm/bella
	mkdir -p /mnt/oomerfarm/bella/renders
	mkdir -p /mnt/oomerfarm/installers
	chown oomerfarm.oomerfarm /mnt/oomerfarm
	chown oomerfarm.oomerfarm /mnt/oomerfarm/bella
	chown oomerfarm.oomerfarm /mnt/oomerfarm/bella/renders
	chcon -R -t samba_share_t /mnt/DeadlineRepository10/
	chcon -R -t samba_share_t /mnt/oomerfarm/
fi

# Set password, confirm password
(echo ${linux_password}; echo ${linux_password}) | smbpasswd -a oomerfarm -s

echo -e "\e[32mDownloading ${mongourl}${mongotar}\e[0m"
curl -O ${mongourl}${mongotar}
MatchFile="$(echo "${mongosha256} ${mongotar}" | sha256sum --check)"
if ! [[ "$MatchFile" == "${mongotar}: OK" ]] ; then
	echo -e "\nChecksum for MongoDB does not match"
	echo -e "\nABORTING: The mongodb download failed is corrupted or has been maliciously modified"
	exit
fi

# Get Thinkbox software
# =====================
echo -e "\n\e[32mInstalling Deadline Renderfarm Software ...\e[0m"
if ! test -f /mnt/DeadlineRepository10/ThinkboxEULA.txt ; then
	echo -e "\nChecking existence of ${thinkboxurl}${thinkboxtar}" 
	if ! (curl -s --head --fail -o /dev/null "${thinkboxurl}${thinkboxtar}" ); then
		echo -e "\e[31mFAIL:\e[0m no Thinkbox Software at ${thinkboxurl}${thinkboxtar}"
			exit
	fi

	echo $thinkboxtar
	if ! ( test -f "${thinkboxtar}" ); then
		echo -e "\n\e[32mDownloading AWS Thinkbox Deadline Software 900MB+ ...\e[0m"
		curl -O ${thinkboxurl}${thinkboxtar}
	fi
	MatchFile="$(echo "${thinkboxsha256} ${thinkboxtar}" | sha256sum --check)"
	echo $MatchFile
	if [ "$MatchFile" == "${thinkboxtar}: OK" ] ; then
	    echo -e "\e[32mExtracting ${thinkboxurl}${thinkboxtar}\e[0m\n"
	    tar --skip-old-files -xzf ${thinkboxtar}
	else
	    echo "\e[31mFAIL:\e[0m ${thinkboxtar} checksum failed, file possibly maliciously altered on AWS"
	    exit
	fi

	# Installers for workers
	mkdir -p /mnt/oomerfarm/installers
        cp DeadlineClient-${thinkboxversion}-linux-x64-installer.run /mnt/oomerfarm/installers

	# Cleanup
	rm DeadlineClient-${thinkboxversion}-linux-x64-installer.run.sig
	rm DeadlineRepository-${thinkboxversion}-linux-x64-installer.run.sig
	rm AWSPortalLink-*-linux-x64-installer.run
	rm AWSPortalLink-*-linux-x64-installer.run.sig
	echo -e "\e[32m${thinkboxrun} --mode unattended --requireSSL false --dbLicenseAcceptance accept --unattendedmodeui none --prefix /mnt/DeadlineRepository10 --dbhost ${nebula_ip} --prepackagedDB ${mongotar} --dbInstallationType prepackagedDB --installmongodb true --dbOverwrite true\e[0m"
	${thinkboxrun} --mode unattended --requireSSL false --dbLicenseAcceptance accept --unattendedmodeui none --prefix /mnt/DeadlineRepository10 --dbhost ${nebula_ip} --prepackagedDB ${mongotar} --dbInstallationType prepackagedDB --installmongodb true --dbOverwrite true
	sed -i "s/bindIpAll: true/bindIp: ${nebula_ip}/g" /opt/Thinkbox/DeadlineDatabase10/mongo/data/config.conf
	/etc/init.d/Deadline10db restart

	# [TODO] Thinkbox installs mongod and runs as root, should use low security user 
	# [TODO] Since files are already created, will have to recursively chown
	chown root.root /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod
	chown root.root /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongo
	chown root.root /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongos
	chcon -t bin_t /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod

	echo -e "\n\n\e[31mYou accept AWS Thinkbox Deadline EULA when installing:\e[0m"
	cat /mnt/DeadlineRepository10/ThinkboxEULA.txt
else
	echo -e "\e[35mDeadline Repository exists...skipping installation\e[0m"
fi

# Install Deadline license forwarder, forced to install all client software
if ! [[ $skip_advanced == "yes" ]]; then
	if ! test -d /opt/Thinkbox/Deadline10/bin ; then
		echo -e "\e[32mInstalling DeadlineClient-${thinkboxversion}-linux-x64-installer.run\e[0m"
		chmod +x /mnt/oomerfarm/installers/DeadlineClient-${thinkboxversion}-linux-x64-installer.run
		echo -e "\e[32m/mnt/oomerfarm/installers/DeadlineClient-${thinkboxversion}-linux-x64-installer.run --mode unattended --unattendedmodeui none --repositorydir /mnt/DeadlineRepository10  --connectiontype Direct --noguimode true --binariesonly true\e[0m"
		/mnt/oomerfarm/installers/DeadlineClient-${thinkboxversion}-linux-x64-installer.run --mode unattended --unattendedmodeui none --repositorydir /mnt/DeadlineRepository10  --connectiontype Direct --noguimode true --binariesonly true
		rm DeadlineClient-${thinkboxversion}-linux-x64-installer.run

cat <<EOF > /var/lib/Thinkbox/Deadline10/licenseforwarder.ini
[Deadline]
LicenseForwarderProcessID=92562
LicenseForwarderMessagingPort=40635
EOF
	chown oomerfarm.oomerfarm /var/lib/Thinkbox/Deadline10/licenseforwarder.ini

cat <<EOF > /var/lib/Thinkbox/Deadline10/deadline.ini
[Deadline]
LicenseMode=LicenseFree
Region=
LauncherListeningPort=17000
LauncherServiceStartupDelay=60
AutoConfigurationPort=17001
SlaveStartupPort=17003
SlaveDataRoot=
RestartStalledSlave=false
NoGuiMode=true
LaunchSlaveAtStartup=0
AutoUpdateOverride=
ConnectionType=Repository
NetworkRoot=/mnt/DeadlineRepository10
DbSSLCertificate=
NetworkRoot0=/mnt/DeadlineRepository10
LicenseForwarderSSLPath=/etc/deadline
EOF

cat <<EOF > /etc/systemd/system/deadlinelicenseforwarder.service
[Unit]
Description=Deadline 10 License Forwarder
After= nebula.service

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/bin/bash -l -c "/opt/Thinkbox/Deadline10/bin/deadlinelicenseforwarder --sslpath /etc/deadline"
ExecStop=/opt/Thinkbox/Deadline10/bin/deadlinelauncher -shutdownall
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF
		systemctl enable --now deadlinelicenseforwarder
	else
 		echo -e "\e[35mDeadline Client software already exists in /opt/Thinkbox/Deadline10/bin ...skipping installation\e[0m"
	fi
fi

mkdir -p /mnt/DeadlineRepository10/custom/plugins/BellaRender
mkdir -p /mnt/DeadlineRepository10/custom/scripts/Submission
cp DeadlineRepository10/custom/plugins/BellaRender/BellaRender.param /mnt/DeadlineRepository10/custom/plugins/BellaRender/BellaRender.param
cp DeadlineRepository10/custom/plugins/BellaRender/BellaRender.py /mnt/DeadlineRepository10/custom/plugins/BellaRender/BellaRender.py
cp DeadlineRepository10/custom/plugins/BellaRender/bella.ico /mnt/DeadlineRepository10/custom/plugins/BellaRender/bella.ico
cp DeadlineRepository10/custom/scripts/Submission/BellaRender.py /mnt/DeadlineRepository10/custom/scripts/Submission/BellaRender.py

# [TODO] switch to ssl for better security
#sed -i "s/Authenticate=.*/Authenticate=False/g" /mnt/DeadlineRepository10/settings/connection.ini

echo -e "\e[32mDownloading Bella path tracer ...\e[0m"
curl -O https://downloads.bellarender.com/bella_cli-${bella_version}.tar.gz
MatchFile="$(echo "${bellasha256} bella_cli-${bella_version}.tar.gz" | sha256sum --check)"
mkdir -p /mnt/oomerfarm/installers
if [ "$MatchFile" = "bella_cli-${bella_version}.tar.gz: OK" ] ; then
	cp bella_cli-${bella_version}.tar.gz /mnt/oomerfarm/installers/
	rm bella_cli-${bella_version}.tar.gz 
else
	rm bella_cli-${bella_version}.tar.gz 
	echo "\e[31mFAIL:\e[0m bella checksum failed, may be corrupted or malware"
	exit
fi

curl -L https://bellarender.com/doc/scenes/orange-juice/orange-juice.bsz -o /mnt/oomerfarm/bella/orange-juice.bsz
chown oomerfarm.oomerfarm /mnt/oomerfarm/bella/orange-juice.bsz

if [ "$nebula_name" == "i_agree_this_is_unsafe" ]; then
        echo -e "\n\e[32mFinished oomerfarm hub setup. Ready to distribute renderfarm work\e[0m"
        echo -e "Enter \e[36m\e[5m${public_ip}\e[0m\e[0m when asked for \e[32mhub\e[0m ip address"
        echo -e "The \e[32mhub\e[0m only tracks jobs and servers files"
        echo -e "\e[36mNow you need some powerful Linux machines to do rendering\e[0m"
        echo -e " - ssh and run \e[32mbash bootstrapworker.sh\e[0m"
        echo -e "To submit jobs, from desktop/laptop, join the VPN by running \e[36mbash joinoomerfarm.sh\e[0m" 
	echo -e "\e[34mKeep window open to keep VPN alive\e[0m"
        echo -e " - with username \e[36moomerfarm\e[0m password \e[36moomerfarm\e[0m"
        echo -e " - mount folder \e[36msmb://hub.oomer.org/DeadlineRepository10\e[0m ( Windows //hub.oomer.org/DeadlineRespository )"
        echo -e " - mount folder \e[36msmb://hub.oomer.org/oomerfarm\e[0m ( Windows //hub.oomer.org/oomerfarm )"
        echo -e " - install Deadline Client software \e[36mhttps://www.awsthinkbox.com\e[0m"
        echo -e "You are on the \e[31mnot-so-secret keys\e[0m. Deploy a \e[32msecure renderfarm\e[0m by following instructions at https://github.com/oomer/oomerfarm"
else
        echo -e "\n\e[32mOomerfarm hub setup completed. Ready to distribute renderfarm work\e[0m"
        echo -e "Remaining steps:"
        echo -e "Enter \e[36m\e[5m${public_ip}\e[0m\e[0m when asked for \e[32mhub\e[0m address"
        echo -e "1. \e[32m[DONE]\e[0m Made secret keys on a trusted desktop/laptop"
        echo -e "2. \e[32m[YOU ARE HERE]\e[0m on this computer you ran \e[36mbash bootstraphub.sh\e[0m"
        echo -e "\e[36mNow you need some powerful Linux machines to do rendering\e[0m"
        echo -e "3. ssh and run \e[32mbash bootstrapworker.sh\e[0m"
        echo -e "4. To submit jobs, from desktop/laptop, run \e[36mbash joinoomerfarm.sh\e[0m to join VPN"
	echo -e "\e[34mKeep window open to keep VPN alive\e[0m"
	if [ "$linux_password" == "oomerfarm" ]; then
        	echo -e " - with username \e[36moomerfarm\e[0m password \e[36moomerfarm\e[0m"
	else
        	echo -e " - with username \e[36moomerfarm\e[0m password \e[36mYOU\e[0m set above"
	fi
        echo -e " - mount folder \e[36msmb://hub.oomer.org/DeadlineRepository10\e[0m ( Windows //hub.oomer.org/DeadlineRepository ) "
        echo -e " - mount folder \e[36msmb://hub.oomer.org/oomerfarm\e[0m ( Windows //hub.oomer.org/oomerfarm )"
        echo -e " - install Deadline Client software \e[36mhttps://www.awsthinkbox.com\e[0m"
fi
