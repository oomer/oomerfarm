#!/bin/bash
# oomerfarm is a personal renderfarm deployed using simple bash scripts and Google Drive
# consisting of: 
#		a hub hostrunning Alma/Rocky Linux 8.x, Samba, MongoDB in the cloud
#		an enterprise grade mesh VPN, simplifying internet wide connectivity 
#		worker hosts for rendering running locally or in the cloud
#		boss hosts for submitting jobs and administrative access	

# Use of google drive is the lowest common storage method, S3 storage is also supported
# Use of crunchbits.com for hub is to streamline docs
# [tested] MacOS Ventura 13.4

nebula_version="v1.7.2"
echo
echo -e "============================================================================"
echo -e "OOMERFARM: an occasional renderfarm using ssh, bash scripts and Google Drive"
echo -e "============================================================================"
echo
echo -n "keyoomerfarm.sh creates a certificate-authority to make cryptographic based"
echo -n " credentials and packages them into encrypted keybundles that you"
echo -n " can email or post on Google Drive publicly. The certificates created are similar"
echo -n " to the ones downloaded by web browsers from Amazon to secure the communication"
echo -e " channel from prying eyes when passwords and credit card details are transmitted"
echo
echo -e "In the same way that the .ssh folder needs to be protected, the  _oomerfarm_ subdirectory"
echo -e "needs only be stored on a secure computer"
echo -n "The open source Nebula project provides a VPN that allows oomerfarm to secure your"
echo -e " renderfarm while using public internet infrastructure."
echo

if ! ( test -d "_oomerfarm_" ); then
	mkdir -p _oomerfarm_/nebula-authority
	mkdir -p _oomerfarm_/bin
fi

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



while :
do
	echo -e "\nEnter passphrase to encrypt keybundles...( typing is ghosted )"
	read -rs encryption_passphrase
	if [ -z "$encryption_passphrase" ]; then
	    echo "FAIL: invalid empty passphrase"
	    exit
	fi
	echo "Verifying: re-enter password"
	read -rs encryption_passphrase_check 
	    if [[ "$encryption_passphrase" == "$encryption_passphrase_check" ]]; then
		break
	    fi
	echo "Passphrase verification failed! Try again."
done


ca_name_default="oomerfarm"
ca_name=$ca_name_default
#echo -e "\nEnter Nebula certificate authority name"
#read -p "default ( $ca_name_default ): " ca_name
#if [ -z $ca_name ]; then
#	ca_name=$ca_name_default
#fi

ca_duration_default="8766h0m0s"
echo -e "\nHow long should certificates be valid? ( After this time the netowrk will stop )"
read -p "default ( $ca_duration_default ): " ca_duration
if [ -z $ca_duration ]; then
	ca_duration=$ca_duration_default
fi

# Generate certificate authority ONCE and valid for a few years
# signed certificates last one second less than ca 
# [TODO] support encrypted signing
# =============================================================
if ! ( test -f "./_oomerfarm_/nebula-authority/ca.crt" ); then
 	./_oomerfarm_/bin/nebula-cert ca -name $ca_name -duration $ca_duration -out-crt ./_oomerfarm_/nebula-authority/ca.crt -out-key ./_oomerfarm_/nebula-authority/ca.key
fi

echo -e "/nSTOP: Wait until your cloud server has an internet IPv4 address..."
echo -e "What is the internet ip address of your \"hub\" cloud server?"
read -p " " lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
	echo "Cannot continue without knowing the internet ip address of your cloud server"	
	exit
fi

lighthouse_name_default="hub"
# a hub is an artificial composite of a Nebula lighthouse, a Deadline Repository ove Samba server and a MongoDB server
echo -e "\nEnter Nebula hub name"
read -p "default ( $lighthouse_name_default ): " lighthouse_name
if [ -z $lighthouse_name ]; then
	lighthouse_name=$lighthouse_name_default
fi

lighthouse_nebula_ip_default="10.10.0.1"
echo -e "\nEnter Nebula lighthouse ip address IPv4"
read -p "default ( $lighthouse_nebula_ip_default ): " lighthouse_nebula_ip
if [ -z $lighthouse_nebula_ip ]; then
	lighthouse_nebula_ip=$lighthouse_nebula_ip_default
fi

lighthouse_internet_port_default="42042"
echo -e "\nEnter Nebula lighthouse internet port"
read -p "default ( $lighthouse_internet_port_default ): " lighthouse_internet_port
if [ -z $lighthouse_internet_port ]; then
	lighthouse_internet_port=$lighthouse_internet_port_default
fi


octet1=10
octet2=10
octet3=0
octet4=1
mask=16

echo -e "\nEnter Nebula network CIDR for hub"
# IFS = internal field separator, './' are 2 x single char delimiters
IFS='./' read -p "default ( ${octet1}.${octet2}.${octet3}.${octet4}/${mask} ): " -ra addr
if ! [ -z $addr ]; then
	octet1="${addr[0]}"
	octet2="${addr[1]}"
	octet3="${addr[2]}"
	octet4="${addr[3]}"
	mask="${addr[4]}"
fi

if ! test -d "_oomerkeys_" ; then
	mkdir -p _oomerkeys_
fi

if ! test -d "_oomerfarm_/${lighthouse_name}" ; then
	mkdir -p ./_oomerfarm_/${lighthouse_name}
fi 


# Nebula sign hub
# ===============
./_oomerfarm_/bin/nebula-cert sign -name "${lighthouse_name}" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "oomerfarm,oomerfarm-hub" -out-crt "./_oomerfarm_/${lighthouse_name}/${lighthouse_name}.crt" -out-key "./_oomerfarm_/${lighthouse_name}/${lighthouse_name}.key" -ca-crt "_oomerfarm_/nebula-authority/ca.crt" -ca-key "_oomerfarm_/nebula-authority/ca.key"

cp ./_oomerfarm_/nebula-authority/ca.crt ./_oomerfarm_/${lighthouse_name}

# Need to cd to get proper relative paths for tar
origdir=$(pwd)
cd _oomerfarm_

find "./${lighthouse_name}" -type f -exec tar -rvf ${lighthouse_name}.keybundle {} \;
openssl enc -aes-256-cbc -salt -pbkdf2 -in "./${lighthouse_name}.keybundle" -out $origdir/_oomerkeys_/${lighthouse_name}.keybundle.enc -pass stdin <<< "$encryption_passphrase"
cd $origdir


# Worker stage
# ============

workernum_default=10
echo -e "/nHow many workers do you want?"
read -p "default ( $workernum_default ): " workernum
if [ -z $workernum ]; then
	workernum=$workernum_default
fi

worker_prefix_default="worker"
echo -e "/nWhat would you like to call your workers?"
echo "When requesting 10 workers the first gets id 0001 and the last 0010"
echo "The name you choose gets prefixed to the id, \"worker\" = worker0001 to worker0010"
read -p "default ( $worker_prefix_default ): " worker_prefix
if [ -z $worker_prefix ]; then
	worker_prefix=$worker_prefix_default
fi

octet1=10
octet2=10
octet3=99
octet4=1
mask=16

echo -e "\nEnter Nebula worker network CIDR"
# IFS = internal field separator, './' are 2 x single char delimiters
IFS='./' read -p "default ( ${octet1}.${octet2}.${octet3}.${octet4}/${mask} ): " -ra addr
if ! [ -z $addr ]; then
	octet1="${addr[0]}"
	octet2="${addr[1]}"
	octet3="${addr[2]}"
	octet4="${addr[3]}"
	mask="${addr[4]}"
fi

if ! test -d "_oomerfarm_/${worker_prefix}"; then
	mkdir "./_oomerfarm_/${worker_prefix}"
fi

# {TODO] keep track of workercount
for ((workercount = 1 ; workercount <= "${workernum}" ; workercount++)); do
	./_oomerfarm_/bin/nebula-cert sign -name "${worker_prefix}$(printf %04d $workercount)" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "oomerfarm" -out-crt "./_oomerfarm_/${worker_prefix}/${worker_prefix}$(printf %04d $workercount).crt" -out-key "./_oomerfarm_/${worker_prefix}/${worker_prefix}$(printf %04d $workercount).key" -ca-crt "./_oomerfarm_/nebula-authority/ca.crt" -ca-key "./_oomerfarm_/nebula-authority/ca.key" 

	((octet4++))
	if [[ octet4 -eq 255 ]]; then
		((octet3++))
		octet4=1
		if [[ octet3 -eq 255 ]]; then
			((octet2++))
			## WARNING you are probably making too many certificates if you get here
			if [[ octet2 -eq 255 ]]; then
				((octet1++))
				if [[ octet1 -eq 255 ]]; then
					break
				fi
			fi
		fi
	fi
done

cp ./_oomerfarm_/nebula-authority/ca.crt "./_oomerfarm_/${worker_prefix}"


origdir=$(pwd)
cd ./_oomerfarm_
find "${worker_prefix}" -type f -exec tar -rvf ${worker_prefix}.keybundle {} \;
openssl enc -aes-256-cbc -salt -pbkdf2 -in "${worker_prefix}.keybundle" -out ${origdir}/_oomerkeys_/${worker_prefix}.keybundle.enc -pass stdin <<< "$encryption_passphrase" 
rm "${worker_prefix}.keybundle"
cd $origdir

# Boss stage
# ==========
echo -e "\nChallenge/Answer stage for the oomerfarm boss"
echo -e "============================================"

boss_name_default="boss"
echo -e "\nEnter Nebula boss name"
read -p "default ( $boss_name_default ): " boss_name
if [ -z $boss_name ]; then
	boss_name=$boss_name_default
fi


octet1=10
octet2=10
octet3=0
octet4=100
mask=16


echo -e "\nEnter Nebula boss network CIDR"
# IFS = internal field separator, './' are 2 x single char delimiters
IFS='./' read -p "default ( ${octet1}.${octet2}.${octet3}.${octet4}/${mask} ): " -ra addr
if ! [ -z $addr ]; then
	octet1="${addr[0]}"
	octet2="${addr[1]}"
	octet3="${addr[2]}"
	octet4="${addr[3]}"
	mask="${addr[4]}"
fi

if ! test -d "./_oomerfarm_/${boss_name}"; then
	mkdir -p "./_oomerfarm_/${boss_name}"
fi

# boss Nebula sign, tar, encrypt
./_oomerfarm_/bin/nebula-cert sign -name "${boss_name}" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "oomerfarm,oomerfarm-hub,oomerfarm-admin" -out-crt "./_oomerfarm_/${boss_name}/${boss_name}.crt" -out-key "./_oomerfarm_/${boss_name}/${boss_name}.key" -ca-crt "./_oomerfarm_/nebula-authority/ca.crt" -ca-key "./_oomerfarm_/nebula-authority/ca.key"

# setup local nebula files
if ! test -d "./_oomerfarm_/boss"; then
	mkdir -p "./_oomerfarm_/boss"
	cp ./_oomerfarm_/${boss_name}/${boss_name}.crt ./_oomerfarm_/boss
	cp ./_oomerfarm_/${boss_name}/${boss_name}.key ./_oomerfarm_/boss
	cp ./_oomerfarm_/nebula-authority/ca.crt ./_oomerfarm_/boss
fi

cat <<EOF > ./_oomerfarm_/boss/config.yml
# boss config.yml no incoming except ping

pki:
  ca: ./_oomerfarm_/nebula-authority/ca.crt
  cert: ./_oomerfarm_/boss/${boss_name}.crt
  key: ./_oomerfarm_/boss/${boss_name}.key

# init script should replace the strings with the actual values 
# or can just be done manually by hand
static_host_map:
  "${lighthouse_nebula_ip}": ["${lighthouse_internet_ip}:${lighthouse_internet_port}"]

lighthouse:
  am_lighthouse: false
  interval: 60

listen:
  host: 0.0.0.0
  port: 4242

host:
  - "${lighthouse_nebula_ip}"

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

origdir=$(pwd)
# copy ca certificate to security bundle staging area
cp ./_oomerfarm_/nebula-authority/ca.crt ./_oomerfarm_/${boss_name}
cp ./_oomerfarm_/boss/config.yml ./_oomerfarm_/${boss_name}
cd ./_oomerfarm_

find "${boss_name}" -type f -exec tar -rvf ${boss_name}.keybundle {} \;
openssl enc -aes-256-cbc -salt -pbkdf2 -in "${boss_name}.keybundle" -out $origdir/_oomerkeys_/${boss_name}.keybundle.enc -pass stdin <<< "$encryption_passphrase" 
rm "${boss_name}.keybundle"
cd $origdir


echo -e "\nCredentials are ready to use"
echo -e "=============================="
echo -e "\nPut these files on Google Drive:"
echo -e "\t./_oomerkeys_/${lighthouse_name}.keybundle.enc"
echo -e "\t./_oomerkeys_/${worker_prefix}.keybundle.enc" 
echo -e "\t./_oomerkeys_/${boss_name}.keybundle.enc"

echo -e "Google Drive share each flle ( Anyone with link )"
echo -e "Write down URL ( Copy link )"
echo -e "If TOPSECRET keys have been compromised, revoke keys on each host's Nebula config.yml"
echo -e "or wipe out _oomerfarm_ , rerun keyoomfarm.sh to create brand new keys"

