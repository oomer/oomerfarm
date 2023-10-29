#!/bin/bash

# joinoomerfarm.sh
# Using "boss" credentials created with keyoomerfarm.sh or the not-so-secure test drive keys embedded below, this script joins a Nebula Virtual Private Network. NOT for hub or worker machines.
# Tested on MacoOS Ventura, Windows 10,11


# Check for existing boss credentials only macos and linux
# ===================================
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]] ; then
        if test -d .oomer/person/person1; then
                echo -e "\n================================================================="
                echo -e "The authenticity of this script cannot be guaranteed unless it comes from https://github.com/oomer/oomerfarm"
                echo -e "Read the code if you can, or check the md5 hash posted on https://github.com/oomer/oomerfarm"
                echo -e "sudo .oomer/bin/nebula is required run a VPN"
                echo "Enter password to elevate the permissions of this scripts"
                sudo .oomer/bin/nebula -config .oomer/person/person1/config.yml
                exit
        fi
fi

mkdir -p .oomer/person/i_agree_this_is_unsafe
nebula_version="v1.7.2"

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

echo -e "\nWhat is the public ip address of the hub machine"
read -p "x.x.x.x::" lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
        echo "Cannot continue without public ip address of hub"
        exit
fi

# TestDrive unsage credentials
# Your Nebula Virtual Private Network can be accessed by these keys
# The "boss" credentials have membership in BOTH oomerfarm and oomerfarm_admin groups
# Nebula built-in firewall allows port 22/tcp ssh access to the hub and worker hosts
# hub and workers are only in the oomerfarm group which does not permit ssh access to the "boss"
# all Nebula hosts can ping each other

cat <<EOF > .oomer/person/i_agree_this_is_unsafe/ca.crt
-----BEGIN NEBULA CERTIFICATE-----
CjcKBW9vbWVyKKCT96kGMKCWj/UGOiDCsJ2dvXr5msWq8IrIDgi7ZGImzOASL4UG
ICFwLtM1REABEkBqk1Vrrzk33Vja+UPNyG/TBqn5ZzKV1CUjsH2e1k1mMQxwUUgE
0bGzMkHAJ6gPfQ3YVHHn6oWk/c4F7Z3u6bQN
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > .oomer/person/i_agree_this_is_unsafe/person1.crt
-----BEGIN NEBULA CERTIFICATE-----
CnsKB3BlcnNvbjESCYGU3FKAgPz/DyIFb29tZXIiBnNlcnZlciIGcGVyc29uKNCT
96kGMJ+Wj/UGOiAPDXUGzvQwXHGXQ10GeDvNhQENyf5d8HkJoEHhX+/ZaEog4ZcT
EoWXlG8TopKaq7X7FVZ/5Pobx2uVfKvJhwAgGaMSQHRilR4jv5xqcWjkOdXjwpVl
UYLoUk2n9vXCthBoeawpCQvwi+XWFG6QNrPXu8HDviLfDuxgTee+E1WEWcwmYwM=
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > .oomer/person/i_agree_this_is_unsafe/person1.key
-----BEGIN NEBULA X25519 PRIVATE KEY-----
eL5x5N4vQkL9xPEJfdcru5InW+Mfmba2HekGX1I0OoU=
-----END NEBULA X25519 PRIVATE KEY-----
EOF


if [[ "$OSTYPE" == "msys"* ]]; then
        oomerfarm_path=$(cygpath -w -p $(pwd))
        ca_path="\\.oomer\\person\\i_agree_this_is_unsafe\\ca.crt"
        crt_path="\\.oomer\\person\\i_agree_this_is_unsafe\\person1.crt"
        key_path="\\.oomer\\person\\i_agree_this_is_unsafe\\person1.key"

else
        oomerfarm_path="."
        ca_path="/.oomer/person/i_agree_this_is_unsafe/ca.crt"
        crt_path="/.oomer/person/i_agree_this_is_unsafe/person1.crt"
        key_path="/.oomer/person/i_agree_this_is_unsafe/person1.key"
fi

cat <<EOF > .oomer/person/i_agree_this_is_unsafe/config.yml
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

listen:
  host: 0.0.0.0
  port: 0

host:
  - "10.87.0.1"

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
                echo -e "\n.oomer/bin/${executable} has been tampered with"a
                echo "Aborting"
                exit
        fi
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
        MatchFile="$(echo "${nebulasha256}  .oomer/bin/${executable}" | shasum -a 256 --check)"
        if ! [ "$MatchFile" == ".oomer/bin/${executable}: OK" ] ; then
                echo -e "\n.oomer/bin/${executable} has been tampered with"
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
        sudo .oomer/bin/nebula -config .oomer/person/i_agree_this_is_unsafe/config.yml
fi

if [[ "$OSTYPE" == "msys"* ]]; then
        echo $(pwd)

cat <<EOF > ~/Desktop/joinoomerfarm.bat
${oomerfarm_path}\\.oomer\\bin\\nebula.exe -config ${oomerfarm_path}\\.oomer\\person\\i_agree_this_is_unsafe\\config.yml
EOF

	echo -e "On \e[32mdesktop\e[0m, right click \e[37m\e[5mjoinoomerfarm.bat\e[0m\e[0m, Run as adminstrator"
	echo -e "Do not run this script if it did not come from  https://github.com/oomer/oomerfarm"
fi

