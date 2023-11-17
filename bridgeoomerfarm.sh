#!/bin/bash

# bridgeoomerfarm.sh
# Bridges user computer to oomerfarm private network. 
# Using your own keys created with becomesecure.sh or the "i_agree_this_is_unsafe" testdrive keys embedded below, this script joins a Nebula Virtual Private Network. 
# - allows mounting network directory from oomerfarm hub
# - allows render submissions and monitoring oomerfarm workers
# - NOT for hub or worker machines.
# - Tested on MacoOS Ventura, Windows 10,11

lighthouse_internet_ip_default="x.x.x.x"
lighthouse_nebula_ip="10.87.0.1"

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

nebula_version="v1.7.2"
nebula_config_create_path=""
nebula_config_path=""


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

	#if test -d .oomer/server; then
	#	existing_keys="$(ls .oomer/server) skip"
	#	if ! [ -z existing_keys ];then
	#		select server_key in $existing_keys
	#		do
	#			break
	#		done
	#		if ! [[ $existing_keys == "skip" ]]; then
	#			nebula_config_create_path=.oomer/server/${server_key}/config.yml
	#		else
	#			exit
	#		fi
	#	else
	#		echo "Invalid state"
	#		exit
	#	fi
	#fi

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


# Download Nebula from github once
# Ensure integrity of executables that will run as administrator
# ==============================================================
if ! ( test -d ".oomer/bin" ); then
        mkdir -p .oomer/bin
        echo -e "\nDownloading Nebula ${nebula_version} ..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                nebularelease="nebula-linux-amd64.tar.gz"
                nebulasha256="4600c23344a07c9eda7da4b844730d2e5eb6c36b806eb0e54e4833971f336f70"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
                nebularelease="nebula-darwin.zip"
                nebulasha256="e4e349f23ff7137c5e749c8a3b32631956aff2d88cef09254b02bbdd100e7b9c"
        elif [[ "$OSTYPE" == "msys"* ]]; then
                nebularelease="nebula-windows-amd64.zip"
                nebulasha256="e65b7de82a4d99b8c6657ffaf4c0437a4c576ab3e3ceca022fbdf45fae438b03"
        else
                echo -e "FAIL: Operating system should either be Linux, MacOS or Windows with msys"
                exit
        fi

        curl -L https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease} -o .oomer/bin/${nebularelease}
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                MatchFile="$(echo "${nebulasha256} .oomer/bin/${nebularelease}" | sha256sum --check)"
                if [ "$MatchFile" == ".oomer/bin/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        tar -xvzf .oomer/bin/${nebularelease} --directory .oomer/bin
                else
                        echo "FAIL: .oomer/bin/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi

        elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
                MatchFile="$(echo "${nebulasha256}  .oomer/bin/${nebularelease}" | shasum -a 256 --check)"
                if [ "$MatchFile" == ".oomer/bin/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        unzip .oomer/bin/${nebularelease} -d .oomer/bin
                else
                        echo "FAIL: .oomer/bin/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi
        else
                echo -e "FAIL: unpacking .oomer/bin/${nebula-release}"
                exit
        fi
        chmod +x .oomer/bin/nebula-cert
        chmod +x .oomer/bin/nebula
        rm .oomer/bin/${nebularelease}
fi


if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        executable="nebula"
        nebulasha256="a12789f4f1e803e39a446aa31c66b07e681d6567042928c5250fda9cd2096ca7"
elif [[ "$OSTYPE" == "darwin"* ]]; then
        executable="nebula"
        nebulasha256="a973d80a4af76a2d40f7e5fd217503e7738ba0753f690d602781c29cf4a38eb8"
elif [[ "$OSTYPE" == "msys"* ]]; then
        executable="nebula.exe"
        nebulasha256="39a78919d817ee3a45a3dc0ff9ec473ae1d4ae2dbd82fbacd396ffc604d6d808"
else
        echo -e "FAIL: Operating system should either be Linux, MacOS or Windows with msys"
        exit
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        MatchFile="$(echo "${nebulasha256}  .oomer/bin/${executable}" | sha256sum --check)"
        if ! $[ "$MatchFile" == ".oomer/bin/${executable}: OK" ] ; then
                echo -e "\n.oomer/bin/${executable} has been corrupted or maliciously tampered with"
                echo "Aborting"
                exit
        fi
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
        MatchFile="$(echo "${nebulasha256}  .oomer/bin/${executable}" | shasum -a 256 --check)"
        if ! [ "$MatchFile" == ".oomer/bin/${executable}: OK" ] ; then
                echo -e "\n.oomer/bin/${executable} has been corrupted or maliciously tampered with"
                echo "Aborting"
                exit
        fi
else
        exit
fi


if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]] ; then
	echo -e "\n"
	echo -e "Do not run this script if it did not come from  https://github.com/oomer/oomerfarm"
	echo "Current user, must be admin. Enter password to elevate the permissions of this script"
        sudo .oomer/bin/nebula -config .oomer/user/${user_key}/config.yml
fi

if [[ "$OSTYPE" == "msys"* ]]; then
        echo $(pwd)

cat <<EOF > ~/Desktop/joinoomerfarm.bat
${oomerfarm_path}\\.oomer\\bin\\nebula.exe -config ${oomerfarm_path}\\.oomer\\user\\${user_key}\\config.yml
EOF

	echo -e "On \e[32mdesktop\e[0m, right click \e[37m\e[5mbridgeoomerfarm.bat\e[0m\e[0m, Run as adminstrator"
	echo -e "Do not run this script if it did not come from  https://github.com/oomer/oomerfarm"
fi

