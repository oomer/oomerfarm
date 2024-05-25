#!/bin/bash

# bridgeoomerfarm.sh
# Bridges user computer to oomerfarm private network. 
# Using your own keys created with becomesecure.sh or the "i_agree_this_is_unsafe" testdrive keys embedded below, this script joins a Nebula Virtual Private Network. 
# - allows mounting network directory from oomerfarm hub
# - allows render submissions and monitoring oomerfarm workers
# - NOT for hub or worker machines.
# - Tested on MacoOS Ventura, Windows 10,11
# - when run under macos or msys windows, do a .oomer install
# - when run under linux do a /etc/nebula install


lighthouse_internet_ip_default="x.x.x.x"
lighthouse_nebula_ip="10.87.0.1"
lighthouse_internet_port="42042"
# additional lighthouses must be added manually

if test -f .oomer/.last_lighthouse_internet_ip; then
	lighthouse_internet_ip_default=$(cat .oomer/.last_lighthouse_internet_ip)
fi

echo -e "\nEnter ip address of oomerfarm hub computer"
echo -e "If this machine is in the cloud, use its public internet address"
echo -e "otherwise use ip address assigned by your home router"
read -p "( default: $lighthouse_internet_ip_default): " lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
	if [[ $lighthouse_internet_ip_default == "x.x.x.x" ]]; then
		echo "Can't continue without a useable ip address..."
		exit
	else
		n='([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
		if [[ $lighthouse_internet_ip_default =~ ^$n(\.$n){3} ]]; then
			lighthouse_internet_ip=$lighthouse_internet_ip_default
		else
			echo "Can't continue, $lighthouse_internet_ip_default is NOT a useable ip address..."
			exit
		fi
	fi
fi
echo $lighthouse_internet_ip > .oomer/.last_lighthouse_internet_ip
echo $lighthouse_internet_ip

nebula_version="v1.9.0"
nebula_config_create_path=""
nebula_config_path=""


# [TODO] currently linux so will require download of encrypted keybundles
# Will also need macos and windows users that do not run becomesecure.sh to get keys
if [[ "$OSTYPE" == "linux-gnu"* ]] ; then
	echo -e "\n\e[36m\e[5mURL\e[0m\e[0m to \e[32mxxxx.keys.encrypted\e[0m"
        read -p "Enter: " keybundle_url
        if [ -z "$keybundle_url" ]; then
                echo -e "\e[31mFAIL:\e[0m URL cannot be blank"
                exit
        fi

        echo -e "\nENTER \e[36m\e[5mpassphrase\e[0m\e[0m to decode \e[32mxxxx.key.encypted\e[0m YOU set in \"keyauthority.sh\"  ( keystrokes hidden )"
        IFS= read -rs encryption_passphrase < /dev/tty
        if [ -z "$encryption_passphrase" ]; then
                echo -e "\n\e[31mFAIL:\e[0m Invalid empty passphrase"
                exit
        fi

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
				curl -L "https://drive.google.com/uc?export=download&id=$googlefileid" -o ${worker_prefix}.keys.encrypted
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
		curl -L -o xxx.keys.encrypted "${keybundle_url}" 
	fi

	# decrypt worker.keybundle.enc
	# ============================
	while :
	do
	    if openssl enc -aes-256-cbc -pbkdf2 -d -in xxx.keys.encrypted -out xxx.tar -pass file:<( echo -n "$encryption_passphrase" ) ; then
		rm xxx.keys.encrypted
		break
	    else
		echo "WRONG passphrase entered for worker.keys.encrypted, try again"
		echo "Enter passphrase for worker.keys.encrypted, then hit return"
		echo "==============================================================="
		IFS= read -rs $encryption_passphrase < /dev/tty
	    fi 
	done  

	# nebula credentials
	# ==================
	if ! test -d /etc/nebula; then
		mkdir -p /etc/nebula
	fi
	tar --strip-components 1 -xvf xxx.tar -C /etc/nebula

	nebulakeypath="$(ls /etc/nebula/*.key)"
	nebulakeyname="${nebulakeypath##*/}"
	nebulakeybase="${nebulakeyname%.*}"
	if [ -z $nebulakeybase ]; then
		exit
	fi
	chown root.root /etc/nebula/${nebulakeybase}.crt
	chown root.root /etc/nebula/${nebulakeybase}.key
	rm xxx.tar

fi


if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
	if test -d .oomer/user; then
		existing_keys="$(ls .oomer/user) skip"

		if ! [ -z existing_keys ];then
			echo -e "\nChoose user key:"
			select user_key in $existing_keys
			do
				break
			done
			if ! [[ $existing_keys == "skip" ]]; then
				nebula_config_create_path=.oomer/user/${user_key}/config.yml
			fi
		else
			echo "Invalid state"
			exit
		fi

	else
		user_key="i_agree_this_is_unsafe"
		mkdir -p .oomer/user/i_agree_this_is_unsafe
		nebula_config_create_path=.oomer/user/${user_key}/config.yml
		# Your Nebula Virtual Private Network can be accessed by these keys
		# The user keys are in BOTH oomer and person groups
		# Nebula built-in firewall allows port 22/tcp ssh access to the hub and worker hosts
		# hub and workers are only in the oomer group which does not permit ssh access person nodes
		# all Nebula hosts can ping each other

cat <<EOF > .oomer/user/i_agree_this_is_unsafe/ca.crt
-----BEGIN NEBULA CERTIFICATE-----
CjcKBW9vbWVyKKCT96kGMKCWj/UGOiDCsJ2dvXr5msWq8IrIDgi7ZGImzOASL4UG
ICFwLtM1REABEkBqk1Vrrzk33Vja+UPNyG/TBqn5ZzKV1CUjsH2e1k1mMQxwUUgE
0bGzMkHAJ6gPfQ3YVHHn6oWk/c4F7Z3u6bQN
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > .oomer/user/i_agree_this_is_unsafe/i_agree_this_is_unsafe.crt
-----BEGIN NEBULA CERTIFICATE-----
CnsKB3BlcnNvbjESCYGU3FKAgPz/DyIFb29tZXIiBnNlcnZlciIGcGVyc29uKNCT
96kGMJ+Wj/UGOiAPDXUGzvQwXHGXQ10GeDvNhQENyf5d8HkJoEHhX+/ZaEog4ZcT
EoWXlG8TopKaq7X7FVZ/5Pobx2uVfKvJhwAgGaMSQHRilR4jv5xqcWjkOdXjwpVl
UYLoUk2n9vXCthBoeawpCQvwi+XWFG6QNrPXu8HDviLfDuxgTee+E1WEWcwmYwM=
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > .oomer/user/i_agree_this_is_unsafe/i_agree_this_is_unsafe.key
-----BEGIN NEBULA X25519 PRIVATE KEY-----
eL5x5N4vQkL9xPEJfdcru5InW+Mfmba2HekGX1I0OoU=
-----END NEBULA X25519 PRIVATE KEY-----
EOF

	fi

	if [[ "$OSTYPE" == "msys"* ]]; then
		oomerfarm_path=$(cygpath -w -p $(pwd))
		ca_path="\\.oomer\\user\\${user_key}\\ca.crt"
		crt_path="\\.oomer\\user\\${user_key}\\${user_key}.crt"
		key_path="\\.oomer\\user\\${user_key}\\${user_key}.key"

	else
		oomerfarm_path="."
		ca_path="/.oomer/user/${user_key}/ca.crt"
		crt_path="/.oomer/user/${user_key}/${user_key}.crt"
		key_path="/.oomer/user/${user_key}/${user_key}.key"
	fi

	echo "oooo"
	if ! [ -z $nebula_config_create_path ]; then


#cat <<EOF > .oomer/user/${user_key}/config.yml
cat <<EOF > $nebula_config_create_path
pki:
  ca: ${oomerfarm_path}${ca_path}
  cert: ${oomerfarm_path}${crt_path}
  key: ${oomerfarm_path}${key_path}

# init script should replace the strings with the actual values
# or can just be done manually by hand
static_host_map:
  "10.87.0.1": ["${lighthouse_internet_ip}:42042"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "${lighthouse_nebula_ip}"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true

relay:
  am_relay: false
  use_relays: false

tun:
  disabled: false
  dev: nebula0
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
EOF
	fi
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	nebulabindir="/opt/oomer/bin"
else
        nebulabindir=".oomer/bin"
fi
mkdir -p ${nebulabindir}

# Download Nebula from github once
# Ensure integrity of executables that will run as administrator
# On linux, we create a systemd unit
# ==============================================================
if ! ( test -f ".oomer/bin/nebula" ) && ! ( test -f "/opt/oomer/bin/nebula" ); then
        echo -e "\nDownloading Nebula ${nebula_version} ..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                nebularelease="nebula-linux-amd64.tar.gz"
                nebulasha256="f700c0ad7e9f28375ab90111511d3b515671ee4b8e70b0bc92a506e87da975ad"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
                nebularelease="nebula-darwin.zip"
                nebulasha256="0cb110bae40edbc4ce7a2e67389b967cc63931c9b710faa33cd52f2575a12185"
        elif [[ "$OSTYPE" == "msys"* ]]; then
                nebularelease="nebula-windows-amd64.zip"
                nebulasha256="feacd0292ce1afb9fd121fae4f885f35e05ee773a28c129fdaa363d9aebae1dd"
        else
                echo -e "FAIL: Operating system should either be Linux, MacOS or Windows with msys"
                exit
        fi

        curl -L https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease} -o ${nebulabindir}/${nebularelease}
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                MatchFile="$(echo "${nebulasha256} ${nebulabindir}/${nebularelease}" | sha256sum --check)"

                if [ "$MatchFile" == "${nebulabindir}/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        tar -xvzf ${nebulabindir}/${nebularelease} --directory ${nebulabindir}
                else
                        echo "FAIL: ${nebulabindir}/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi

        elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
                MatchFile="$(echo "${nebulasha256}  ${nebulabindir}/${nebularelease}" | shasum -a 256 --check)"
                if [ "$MatchFile" == "${nebulabindir}/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        unzip ${nebulabindir}/${nebularelease} -d ${nebulabindir}
                else
                        echo "FAIL: ${nebulabindir}/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi
        else
                echo -e "FAIL: unpacking ${nebulabindir}/${nebularelease}"
                exit
        fi
        chmod +x ${nebulabindir}/nebula-cert
        chmod +x ${nebulabindir}/nebula
        #rm ${nebulabindir}/${nebularelease}
fi

# This section double checks final hash on executable
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        executable="nebula"
        nebulasha256="785597e7974deaf4a65e71d198a3f93c4c90c1b225ad64d4600e5ecaa175d85d"
elif [[ "$OSTYPE" == "darwin"* ]]; then
        executable="nebula"
        nebulasha256="57c89d539ec449794fba895252d416fb236cd0c7fa8703b921e4b71a1088be3e"
elif [[ "$OSTYPE" == "msys"* ]]; then
        executable="nebula.exe"
        nebulasha256="067e365643109c18a8fcf67d83f04801e57272ef1ad75058814dd9bf6f1ab519"
else
        echo -e "FAIL: Operating system should either be Linux, MacOS or Windows with msys"
        exit
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        MatchFile="$(echo "${nebulasha256}  ${nebulabindir}/${executable}" | sha256sum --check)"
        if ! [ "$MatchFile" == "${nebulabindir}/${executable}: OK" ] ; then
                echo -e "\n${nebulabindir}/${executable} has been corrupted or maliciously tampered with"
                echo "Aborting"
                exit
        fi
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
        MatchFile="$(echo "${nebulasha256}  ${nebulabindir}/${executable}" | shasum -a 256 --check)"
        if ! [ "$MatchFile" == "${nebulabindir}/${executable}: OK" ] ; then
                echo -e "\n${nebulabindir}/${executable} has been corrupted or maliciously tampered with"
                echo "Aborting"
                exit
        fi
else
        exit
fi


if [[ "$OSTYPE" == "darwin"* ]] ; then
	echo -e "\n"
	echo -e "Do not run this script if it did not come from  https://github.com/oomer/oomerfarm"
	echo "Current user, must be admin. Enter password to elevate the permissions of this script"
        sudo ${nebulabindir}/nebula -config .oomer/user/${user_key}/config.yml
fi

if [[ "$OSTYPE" == "msys"* ]]; then
        echo $(pwd)

cat <<EOF > ~/Desktop/bridgeoomerfarm.bat
${oomerfarm_path}\\.oomer\\bin\\nebula.exe -config ${oomerfarm_path}\\.oomer\\user\\${user_key}\\config.yml
EOF

	echo -e "On \e[32mdesktop\e[0m, right click \e[37m\e[5mbridgeoomerfarm.bat\e[0m\e[0m, Run as adminstrator"
	echo -e "Do not run this script if it did not come from  https://github.com/oomer/oomerfarm"
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
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
ExecStart=/opt/oomer/bin/nebula -config /etc/nebula/config.yml
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
  cert: /etc/nebula/${nebulakeybase}.crt
  key: /etc/nebula/${nebulakeybase}.key
static_host_map:
  "$lighthouse_nebula_ip": ["$lighthouse_internet_ip:${lighthouse_internet_port}"]
lighthouse:
  am_lighthouse: false
  interval: 60
  hosts: 
    - "${lighthouse_nebula_ip}"
listen:
  host: 0.0.0.0
  port: 42042
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
EOF
	chmod go-rwx /etc/nebula/config.yml
	systemctl enable nebula.service
	systemctl restart nebula.service

fi
