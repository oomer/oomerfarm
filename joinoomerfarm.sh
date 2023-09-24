#!/bin/bash

# joinoomerfarm.sh
# Using "boss" credentials created with keyoomerfarm.sh or the unsafe TestDrive credentials embedded below, this script joins a Nebula Virtual Private Network. NOT for hub or worker machines.
# Tested on MacoOS Ventura


# Check for existing boss credentials only macos and linux
# ===================================
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]] ; then
        if test -d ./_oomerfarm_/boss; then
                echo -e "\n================================================================="
                echo -e "The authenticity of this script cannot be guaranteed unless it comes from https://github.com/oomer/oomerfarm"
                echo -e "Read the code if you can, or check the md5 hash posted on https://github.com/oomer/oomerfarm"
                echo -e "sudo ./_oomerfarm_/bin/nebula is required run a VPN"
                echo "Enter password to elevate the permissions of this scripts"
                sudo ./_oomerfarm_/bin/nebula -config ./_oomerfarm_/boss/config.yml
                exit
        fi
fi
# Create unsafe TestDrive credentials when they don't exist

#if ! test -d _oomerpath_/testboss; then

mkdir -p _oomerfarm_/bin
mkdir -p _oomerfarm_/testboss
nebula_version="v1.7.2"

# Download Nebula from github once
# Ensure integrity of executables that will run as administrator
# ==============================================================
if ! ( test -d "./_oomerfarm_/bin" ); then
        mkdir -p _oomerfarm_/bin
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

        curl -L https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease} -o ./_oomerfarm_/bin/${nebularelease}
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                MatchFile="$(echo "${nebulasha256} ./_oomerfarm_/bin/${nebularelease}" | sha256sum --check)"
                if [ "$MatchFile" == "./_oomerfarm_/bin/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        tar -xvzf ./_oomerfarm_/bin/${nebularelease} --directory ./_oomerfarm_/bin
                else
                        echo "FAIL: ./_oomerfarm_/bin/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi

        elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
                MatchFile="$(echo "${nebulasha256}  ./_oomerfarm_/bin/${nebularelease}" | shasum -a 256 --check)"
                if [ "$MatchFile" == "./_oomerfarm_/bin/${nebularelease}: OK" ] ; then
                        echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
                        unzip ./_oomerfarm_/bin/${nebularelease} -d ./_oomerfarm_/bin
                else
                        echo "FAIL: ./_oomerfarm_/bin/${nebularelease} checksum failed, file possibly maliciously altered on github"
                        exit
                fi
        else
                echo -e "FAIL: unpacking _oomerfarm_/bin/${nebula-release}"
                exit
        fi
        chmod +x ./_oomerfarm_/bin/nebula-cert
        chmod +x ./_oomerfarm_/bin/nebula
        rm ./_oomerfarm_/bin/${nebularelease}
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

cat <<EOF > ./_oomerfarm_/testboss/ca.crt
-----BEGIN NEBULA CERTIFICATE-----
CjsKCW9vbWVyZmFybSiYiLKoBjD4l7i3BjogjTTL9BqSLvAedIZEKNLoFv/sAGPP
7h38pKP5uGrtwAhAARJAs7hUYjsuDBrT/NN16a1x82492BkqHvO26nYF5cz8z/Wy
bQUbvsDgE2HxTKnCSsbyunu/EDnj7193pM4fRSpnCA==
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > ./_oomerfarm_/testboss/testboss.crt
-----BEGIN NEBULA CERTIFICATE-----
CowBCgRib3NzEgnkgKhQgID8/w8iCW9vbWVyZmFybSINb29tZXJmYXJtLWh1YiIP
b29tZXJmYXJtLWFkbWluKNqIsqgGMPeXuLcGOiCdvf91Av3yQ2t8sQAPCfTJbWwQ
psd73GHJCmbKzqV2Wkog2AVS9DsTXgvOD7SZMZJQnUR0qBC7cTAMaix/b38eGy4S
QBGBsWZMIkAptW6UK6h+7vhMLwTJoqTgIDZz83pYnNoTHcN6Xn1P3qyfHvbb7K8W
s8Lz6KKq5XYPW+ODvmrawAQ=
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > ./_oomerfarm_/testboss/testboss.key
-----BEGIN NEBULA X25519 PRIVATE KEY-----
HHBWyFUcD79p+tMCWLeH5ergQ2N92KAItqihloLGoTI=
-----END NEBULA X25519 PRIVATE KEY-----
EOF


if [[ "$OSTYPE" == "msys"* ]]; then
        oomerfarm_path=$(cygpath -w -p $(pwd))
        ca_path="\\_oomerfarm_\\testboss\\ca.crt"
        crt_path="\\_oomerfarm_\\testboss\\testboss.crt"
        key_path="\\_oomerfarm_\\testboss\\testboss.key"

else
        oomerfarm_path="."
        ca_path="/_oomerfarm_/testboss/ca.crt"
        crt_path="/_oomerfarm_/testboss/testboss.crt"
        key_path="/_oomerfarm_/testboss/testboss.key"
fi

cat <<EOF > ./_oomerfarm_/testboss/config.yml
pki:
  ca: ${oomerfarm_path}${ca_path}
  cert: ${oomerfarm_path}${crt_path}
  key: ${oomerfarm_path}${key_path}

# init script should replace the strings with the actual values
# or can just be done manually by hand
static_host_map:
  "10.10.0.1": ["${lighthouse_internet_ip}:42042"]

lighthouse:
  am_lighthouse: false
  interval: 60

listen:
  host: 0.0.0.0
  port: 0

host:
  - "10.10.0.1"

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
        MatchFile="$(echo "${nebulasha256}  ./_oomerfarm_/bin/${executable}" | sha256sum --check)"
        if ! $[ "$MatchFile" == "./_oomerfarm_/bin/${executable}: OK" ] ; then
                echo -e "\n./_oomerfarm_/bin/${executable} has been tampered with"a
                echo "Aborting"
                exit
        fi
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
        MatchFile="$(echo "${nebulasha256}  ./_oomerfarm_/bin/${executable}" | shasum -a 256 --check)"
        if ! [ "$MatchFile" == "./_oomerfarm_/bin/${executable}: OK" ] ; then
                echo -e "\n./_oomerfarm_/bin/${executable} has been tampered with"
                echo "Aborting"
                exit
        fi
else
        exit
fi

echo -e "\n================================================================="
echo -e "The authenticity of this script cannot be guaranteed unless it comes from github.com/oomer/oomerfarm"
echo -e "sudo ./_oomerfarm_/bin/nebula is required run a VPN"
echo "Enter password to elevate the permissions of this scripts"

if [[ "$OSTYPE" == "msys"* ]]; then
        echo $(pwd)
cat <<EOF > ~/Desktop/joinoomerfarm.bat
${oomerfarm_path}\\_oomerfarm_\\bin\\nebula.exe -config ${oomerfarm_path}\\_oomerfarm_\\testboss\\config.yml
EOF

else
        sudo ./_oomerfarm_/bin/nebula -config ./_oomerfarm_/testboss/config.yml
fi

