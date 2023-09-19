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

year=2023gdrive
nebula_version="v1.7.2"

echo -e "======================================================================================"
echo -e "oomerfarm is a personal renderfarm deployed using simple bash scripts and Google Drive"
echo -e "======================================================================================"
echo -e "Before continuing, launch a cloud machines, RECOMMENDED: https://crunchbits.com"
echo -e "keyoomerfarm.sh is the first script run:"
echo -e "\tMakes a directory called _oomerfarm_ in the current working directory"
echo -e "\tStore the Nebula $nebula_version executables in _oomerfarm_/bin "
echo -e "\tCreate a TOPSECRET Nebula certificate authority in _oomerfarm_/nebula-authority"
echo -e "\tCreate a TOPSECRET MongoDB certificate authority in _oomerfarm_/mongo-authority"
echo -e "\tCreate a TOPSECRET boos key/certificate in _oomerfarm_/boss"

if ! ( test -f "_oomerfarm_/$year" ); then
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

echo -e "\nGlobal challenge/Answer stage for oomerfarm"
echo -e "==========================================="
# Challenge/answer
# ================
echo -e "\nEnter TOPSECRET passphrase to encrypt files"
#echo "By storing these files on Google Drive, \"secrets management\" is simplified"
#echo "Without resorting to manual copy pasting secrets to each node over ssh"
#echo "nor requiring an automation layer like Ansible playbooks"
#echo "nor requiring a third party secrets management layer like Hashicorp Vault"
#echo "We can allow each node to pull bundled secrets from Google Drive during the manual bootstrap step"
#echo "bootstrapping is achieved by ssh'ing to the hubb and worker hosts and running one script on each"
#echo "The batch scripts bootstraphub.sh, bootstrapworker.sh each pull only their required"
#echo "secrets bundle that is decoded on each platform when the passphrase is passed to the script"
#echo "On linux/macos the interactive passphrase is not written to the console using /dev/tty, limiting exposure"
# [TODO] add MFA
echo "Keystrokes hidden"
echo "..."

read -rs encryption_passphrase
if [ -z "$encryption_passphrase" ]; then
    echo "FAIL: invalid empty passphrase"
    exit
fi

ca_name_default="oomerfarm"
echo -e "\nEnter Nebula certificate authority name"
read -p "default ( $ca_name_default ): " ca_name
if [ -z $ca_name ]; then
	ca_name=$ca_name_default
fi

ca_duration_default="8766h0m0s"
echo -e "\nEnter Nebula certificate authority expiry"
echo -e "Your Nebula network connectivity will stop in one year"
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

# hub stage
# =========
echo -e "\nChallenge/Answer stage for the oomerfarm hub"
echo -e "============================================"

echo -e "\nEnter cloud server internet ip address for oomerfarm hub"
echo "A Cloud server must be started to get the IPv4 internet address"
echo "HINT: Get IPv4 address in web control panel of cloud vm provider"
read -p "default ( There is no default ): " lighthouse_internet_ip
if [ -z  $lighthouse_internet_ip ]; then
	echo "Cannot continue without knowing the internet ip address of Nebula Lighthouse"	
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


hub_group_default="i_allow_ssh_smb_mongo_network_connections_from_workers_and_bosses"
echo -e "\nEnter Nebula security group for the hub" 
read -p "default ( $hub_group_default ): " hub_group
if [ -z $hub_group ]; then
	hub_group=$hub_group_default
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

if ! test -d "_oomerfarm_/$year/${lighthouse_name}" ; then
	mkdir -p ./_oomerfarm_/$year/${lighthouse_name}
fi 

# Nebula sign hub
# ===============
./_oomerfarm_/bin/nebula-cert sign -name "${lighthouse_name}" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "${hub_group}" -out-crt "./_oomerfarm_/${year}/${lighthouse_name}/${lighthouse_name}.crt" -out-key "./_oomerfarm_/${year}/${lighthouse_name}/${lighthouse_name}.key" -ca-crt "./_oomerfarm_/nebula-authority/ca.crt" -ca-key "./_oomerfarm_/nebula-authority/ca.key"

cp ./_oomerfarm_/nebula-authority/ca.crt ./_oomerfarm_/${year}/${lighthouse_name}

# Need to cd to get proper relative paths for tar
origdir=$(pwd)
cd _oomerfarm_/$year

find "./${lighthouse_name}" -type f -exec tar -rvf ${lighthouse_name}.keybundle {} \;
openssl enc -aes-256-cbc -salt -pbkdf2 -in "./${lighthouse_name}.keybundle" -out $origdir/_oomerkeys_/${lighthouse_name}.keybundle.enc -pass stdin <<< "$encryption_passphrase"
cd $origdir


# Worker stage
# ============
echo -e "\nChallenge/Answer stage for the oomerfarm worker"
echo -e "==============================================="

workernum_default=10
echo -e "\nEnter number of workers ( aka render nodes )"
read -p "default ( $workernum_default ): " workernum
if [ -z $workernum ]; then
	workernum=$workernum_default
fi

worker_prefix_default="worker"
echo -e "\nEnter prefix for worker names"
echo "When requesting 10 workers the first gets id 0001 and the last 0010"
echo "Prefixing the id with \"worker\" returns worker0001 to worker0010"
echo "SECURITY INFO: Each worker node stores ALL worker certificate/keys"
echo "\tIf enterprise security is required turn on  at-rest image encryption ( ie Google, AWS, et al )"
echo -e "On startup, the hostname MUST have a matching certificate/key stored in /etc/nebula"
echo -e "\tthat gets propagated to the /etc/hostname"
echo -e "\tSpinning up a render node requires the creation of a canonical vm that works and"
echo -e "\tcloning this vm manually via a web control panel or programmatically using cloud cli tools"
echo -e "\tand altering the name of the instance"
echo "if additional workers are required, use keyadditionalworkers.sh to create a seocndary keybundle"
read -p "default ( $worker_prefix_default ): " worker_prefix
if [ -z $worker_prefix ]; then
	worker_prefix=$worker_prefix_default
fi

worker_group_default="i_am_allowed_to_connect_to_hubs_and_bosses_can_connect_to_me"
echo -e "\nEnter Nebula security group for workers" 
read -p "default ( $worker_group_default ): " worker_group
if [ -z $worker_group ]; then
	worker_group=$worker_group_default
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

if ! test -d "_oomerfarm_/${year}/${worker_group}"; then
	mkdir "./_oomerfarm_/${year}/${worker_prefix}"
fi

# {TODO] keep track of workercount
for ((workercount = 1 ; workercount <= "${workernum}" ; workercount++)); do
	./_oomerfarm_/bin/nebula-cert sign -name "${worker_prefix}$(printf %04d $workercount)" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "${worker_group}" -out-crt "./_oomerfarm_/${year}/${worker_prefix}/${worker_prefix}$(printf %04d $workercount).crt" -out-key "./_oomerfarm_/${year}/${worker_prefix}/${worker_prefix}$(printf %04d $workercount).key" -ca-crt "./_oomerfarm_/nebula-authority/ca.crt" -ca-key "./_oomerfarm_/nebula-authority/ca.key" 

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

cp ./_oomerfarm_/nebula-authority/ca.crt "./_oomerfarm_/${year}/${worker_prefix}"

origdir=$(pwd)
cd ./_oomerfarm_/${year}
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


boss_group_default="i_am_the_boss_and_can_connect_everywhere"
echo "Enter Nebula boss security group" 
read -p "default ( $boss_group_default ): " boss_group
if [ -z $boss_group ]; then
	boss_group=$boss_group_default
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

if ! test -d "./_oomerfarm_/$year/${boss_name}"; then
	mkdir -p "./_oomerfarm_/$year/${boss_name}"
fi

# boss Nebula sign, tar, encrypt
./_oomerfarm_/bin/nebula-cert sign -name "${boss_name}" -ip "$octet1.$octet2.$octet3.$octet4/$mask" -groups "${boss_group}" -out-crt "./_oomerfarm_/$year/${boss_name}/${boss_name}.crt" -out-key "./_oomerfarm_/$year/${boss_name}/${boss_name}.key" -ca-crt "./_oomerfarm_/nebula-authority/ca.crt" -ca-key "./_oomerfarm_/nebula-authority/ca.key"

# setup local nebula files
if ! test -d "./_oomerfarm_/boss"; then
	mkdir -p "./_oomerfarm_/boss"
	cp ./_oomerfarm_/$year/${boss_name}/${boss_name}.crt ./_oomerfarm_/boss
	cp ./_oomerfarm_/$year/${boss_name}/${boss_name}.key ./_oomerfarm_/boss
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
cp ./_oomerfarm_/nebula-authority/ca.crt ./_oomerfarm_/$year/${boss_name}
cp ./_oomerfarm_/boss/config.yml ./_oomerfarm_/$year/${boss_name}
cd ./_oomerfarm_/$year

find "${boss_name}" -type f -exec tar -rvf ${boss_name}.keybundle {} \;
openssl enc -aes-256-cbc -salt -pbkdf2 -in "${boss_name}.keybundle" -out $origdir/_oomerkeys_/${boss_name}.keybundle.enc -pass stdin <<< "$encryption_passphrase" 
rm "${boss_name}.keybundle"
cd $origdir


echo -e "\nCredentials are ready to use"
echo -e "=============================="
echo -e "\nPut these files on Google Drive:"
echo -e "\t./_oomerkeys_/${lighthouse_name}.keybundle.enc"
echo -e "\t./_oomerkeys_/${worker_group}.keybundle.enc" 
echo -e "\t./_oomerkeys_/${boss_name}.keybundle.enc"

echo -e "Google Drive share each flle ( Anyone with link )"
echo -e "Write down URL ( Copy link )"
echo -e "If TOPSECRET keys have been compromised, revoke keys on each host's Nebula config.yml"
echo -e "or wipe out _oomerfarm_ , rerun keyoomfarm.sh to create brand new keys"

