#!/bin/sh
if ! test -d _oomerfarm_/testboss; then

	if ! ( test -f "_oomerfarm_/$year" ); then
		mkdir -p _oomerfarm_/bin
		mkdir -p _oomerfarm_/testboss
	fi
	nebula_version="v1.7.2"
	# Download Nebula from github once
	# ================================
	if ! ( test -f "./_oomerfarm_/bin/nebula-cert" ); then
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
	echo -e "\nEnter cloud server internet ip address where you ran bootstraphub.sh"
	read -p ":" lighthouse_internet_ip
	if [ -z  $lighthouse_internet_ip ]; then
		echo "Cannot continue without knowing the internet ip address of oomerfarm hub"	
		exit
	fi

cat <<EOF > ./_oomerfarm_/testboss/ca.crt
-----BEGIN NEBULA CERTIFICATE-----
CjsKCW9vbWVyZmFybSjwkKSoBjDQoKq3BjogGenqWmuQQbB/qoyc21fcODW6COG3
YMRE6gtQOAEsY7dAARJAgEt3iNluWPpkX8nQZGSmMbkVMWAHD0sdRH+SOh+dKQx5
NTyb6yyyAcmlAA4Ua8e9d3ldyy8y9yOvorssHpnpDg==
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > ./_oomerfarm_/testboss/testboss.crt
-----BEGIN NEBULA CERTIFICATE-----
CosBCgRib3NzEgnkgKhQgID8/w8iKGlfYW1fdGhlX2Jvc3NfYW5kX2Nhbl9jb25u
ZWN0X2V2ZXJ5d2hlcmUoiZGkqAYwz6CqtwY6IBikA8udh9sFzCbzCC+NOsqBCixp
0hyFYYca2aArMdQMSiC58qU18KcfOyaFnuGIKU1ZQBesGUhBbuAMrdxsE2zHzBJA
usn0PdOW+ZqlJYaeMVQAUUqWc/eKfkbFqoGw0MYmyGM4NGCh4mN877Y+uIbHGNxI
ZbyAcTWfxer2LJsCJCDKDQ==
-----END NEBULA CERTIFICATE-----
EOF

cat <<EOF > ./_oomerfarm_/testboss/testboss.key
-----BEGIN NEBULA X25519 PRIVATE KEY-----
NQd6x1+oFCCRdOuS/cuqdicYzD36Uj4K1z3GfEEI1ts=
-----END NEBULA X25519 PRIVATE KEY-----
EOF

cat <<EOF > ./_oomerfarm_/testboss/config.yml
# boss config.yml no incoming except ping

pki:
  ca: ./_oomerfarm_/testboss/ca.crt
  cert: ./_oomerfarm_/testboss/testboss.crt
  key: ./_oomerfarm_/testboss/testboss.key

# init script should replace the strings with the actual values 
# or can just be done manually by hand
static_host_map:
  "10.10.0.1": ["${lighthouse_internet_ip}:42042"]

lighthouse:
  am_lighthouse: false
  interval: 60

listen:
  host: 0.0.0.0
  port: 4242

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

	echo -e "\nNote: running sudo ./_oomerfarm_/bin/nebula because to create VPN"
	echo "This requires your user to be an administrator not a standard user"
	sudo ./_oomerfarm_/bin/nebula -config ./_oomerfarm_/testboss/config.yml
else
	if test -d ./_oomerfarm_/boss; then
		sudo ./_oomerfarm_/bin/nebula -config ./_oomerfarm_/boss/config.yml
	else
		sudo ./_oomerfarm_/bin/nebula -config ./_oomerfarm_/testboss/config.yml
	fi
fi

