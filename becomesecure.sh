#!/bin/bash

nebula_version="v1.7.2"
octet0=10
octet1=87
mask=16

mkdir -p .oomer/keyauthority
mkdir -p .oomer/keysencrypted
mkdir -p .oomer/bin
echo -e "\n==========================================================="
echo -e "becomesecure.sh signs keys that secure your private network"
echo "==========================================================="

# Download Nebula from github once
# ================================
if ! ( test -f ".oomer/bin/nebula-cert" ); then
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
	echo -e "Downloading Nebula vpn https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
	curl -L https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease} -o .oomer/bin/${nebularelease}
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		MatchFile="$(echo "${nebulasha256} .oomer/bin/${nebularelease}" | sha256sum --check)"
	elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
		MatchFile="$(echo "${nebulasha256}  .oomer/bin/${nebularelease}" | shasum -a 256 --check)"
	else
		echo -e "FAIL: OS type not recognized"
		exit
	fi

	if [ "$MatchFile" == ".oomer/bin/${nebularelease}: OK" ] ; then
		echo -e "Extracting https://github.com/slackhq/nebula/releases/download/${nebula_version}/${nebularelease}"
		if [[ "$OSTYPE" == "linux-gnu"* ]]; then
			tar -xvzf .oomer/bin/${nebularelease} --directory .oomer/bin
		elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]]; then
			unzip .oomer/bin/${nebularelease} -d .oomer/bin
		fi
	else
		echo "FAIL: .oomer/bin/${nebularelease} checksum failed, file possibly maliciously altered on github or download was corrupted"
		exit
	fi
	chmod +x .oomer/bin/nebula-cert
	chmod +x .oomer/bin/nebula
	rm .oomer/bin/${nebularelease}
fi

# Create certificate authority
# ============================
if ! ( test -f ".oomer/keyauthority/ca.crt" ); then
	ca_name_default="oomer"
	ca_name=$ca_name_default
	ca_duration_default="43800h0m0s"
	echo -e "\nExpiration of certificate authority  VPN will not connect after this date "
	read -p "(default  5 years , ${ca_duration_default}) : " ca_duration
	if [ -z $ca_duration ]; then
		ca_duration=$ca_duration_default
	fi
 	.oomer/bin/nebula-cert ca -name $ca_name -duration $ca_duration -out-crt .oomer/keyauthority/ca.crt -out-key .oomer/keyauthority/ca.key
fi

# Always ask for encryption passphrase, never store
# =================================================
while :
do
	echo -e "\nEnter passphrase to encrypt keys so they can be distributed securely...( typing is ghosted )"
	read -rs encryption_passphrase
	if [ -z "$encryption_passphrase" ]; then
	    echo "FAIL: invalid empty passphrase"
	    exit
	fi
	echo "Verifying: re-enter passphrase"
	read -rs encryption_passphrase_check 
	    if [[ "$encryption_passphrase" == "$encryption_passphrase_check" ]]; then
		break
	    fi
	echo "Passphrase verification failed! Try again."
done
echo

# Forever key making loop
# =======================
		
while :
do
	# oomerfarm is wrapper to make multiple types of keys simultaneously
	# [simplification] oomerfarm currently can only be invoked once 
	echo -e "\nCreate new keys:"
	if test -f .oomer/.oomerfarm_lighthouse_ip; then
		select new_key_type in user worker server lighthouse quit
		do
			break
		done
	else
		select new_key_type in user worker oomerfarm server lighthouse quit
		do
			break
		done
	fi

	# lighthouses are linux machines that have a internet accessible udp port 
	# to allow bridge building between Nebule nodes
	# multiple lighthouses can be added for redundancy
	if [[ $new_key_type == "oomerfarm" ]] ||  [[ $new_key_type == "lighthouse" ]]; then
		# get next ip address sequentially
		lighthouse_prefix="lighthouse"
		if ! test -f .oomer/.lighthouse_ips; then
			octet2=0
			octet3=1
			if [[ $new_key_type =="oomerfarm" ]]; then
				lighthouse_name_default="hub"
			else
				lighthouse_name_default="lighthouse1"
			fi
		else
			# read text list of used ips
			unset -v lighthouse_ip
			while IFS= read -r; do
				lighthouse_ip+=("$REPLY")
			done <.oomer/.lighthouse_ips
			[[ $REPLY ]] && lighthouse_ip+=("$REPLY")
			last_used=${lighthouse_ip[$(( ${#lighthouse_ip[@]} - 1)) ]}
			lighthouse_count=$(( ${#lighthouse_ip[@]} + 1))
			lighthouse_name_default="${lighthouse_prefix}${lighthouse_count}"
			IFS='.' read -ra octet <<< "$last_used"
			octet0=${octet[0]}
			octet1=${octet[1]}
			octet2=${octet[2]}
			octet3=${octet[3]}
			((octet3++))
			if [[ octet3 -eq 255 ]]; then
				echo "only 254 lighthouses are supported 10.87.0.1-10.87.0.254"
				exit
			fi

		fi

		while :
		do
			echo -e "\nEnter lighthouse name ..."
			read -p "default ( $lighthouse_name_default ): " lighthouse_name
			if [ -z $lighthouse_name ]; then
				lighthouse_name=$lighthouse_name_default
			fi
			if [ -z $(grep $lighthouse_name .oomer/.lighthouse_names) ]; then
				break	
			else
				echo "${lighthouse_name} name already exists, try again"
			fi
		done


		lighthouse_nebula_ip="${octet0}.${octet1}.${octet2}.${octet3}"

		mkdir -p ".oomer/lighthouse/${lighthouse_name}"

		echo .oomer/bin/nebula-cert sign -name ${lighthouse_name} -ip "${octet0}.${octet1}.${octet2}.${octet3}/${mask}" -groups "oomer,lighthouse" -out-crt ".oomer/lighthouse/${lighthouse_name}/${lighthouse_name}.crt" -out-key ".oomer/lighthouse/${lighthouse_name}/${lighthouse_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"
		.oomer/bin/nebula-cert sign -name ${lighthouse_name} -ip "${octet0}.${octet1}.${octet2}.${octet3}/${mask}" -groups "oomer,lighthouse" -out-crt ".oomer/lighthouse/${lighthouse_name}/${lighthouse_name}.crt" -out-key ".oomer/lighthouse/${lighthouse_name}/${lighthouse_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"
		cp .oomer/keyauthority/ca.crt .oomer/lighthouse/${lighthouse_name}
		echo "${octet0}.${octet1}.${octet2}.${octet3}" >> .oomer/.lighthouse_ips
		echo "${octet0}.${octet1}.${octet2}.${octet3}" > .oomer/lighthouse/${lighthouse_name}/.nebula_ip

		origdir=$(pwd)
		if test -d .oomer/lighthouse; then
			cd .oomer/lighthouse
			find "${lighthouse_name}" -type f -exec tar -rvf temp.tar {} \;
			if [[ ${new_key_type} == "oomerfarm" ]];then
				echo "${octet0}.${octet1}.${octet2}.${octet3}" > $origdir/.oomer/.oomerfarm_lighthouse_ip
				# [TODO] support more then one lighthouse
				keybundle_name="hub"
			else
				keybundle_name=${lighthouse_name}
			fi
			openssl enc -aes-256-cbc -salt -pbkdf2 -in "temp.tar" -out $origdir/.oomer/keysencrypted/${keybundle_name}.keys.encrypted -pass stdin <<< "$encryption_passphrase"
			rm temp.tar
			cd $origdir
		else
			echo "FAIL: Something is wrong with .oomer/lighthouse"
			exit
		fi

	fi

	# servers are linux machines with roles like file server, database server
	# the nebula firewall allows 22/tcp access for ssh
	# all other firewall rules must be manually added afterwords
	# command line params like --oomerfarm will add specific firewall rules for smb, mongod and license forwarder
	# the keys are put into this directory structure
	# the 10.87.1.x folders keep track of used ip addresses
	# below this directory will human readable folder name of the server
	# subsequently this folder will be tarred and openssl encrypted to allow sharing
	# 
	# max range 1-254
	# .oomer
	# 	|
	#	->servers
	#		|
	#		->10.87.1.1
	#			|
	#			->server1
	# technically, server.crt and server.key could be the constant names
	# but this gets confusing to try to debug, therefore a user friendly name is useful
	# since ip address needs to be unique and name needs to be unique

	if [[ ${new_key_type} == "server" ]]; then
		if ! test -f .oomer/.server; then
			octet2=1
			octet3=1
			server_name_default="server1"
		else
			# read text list of used ips
			unset -v server_ip
			while IFS= read -r; do
				server_ip+=("$REPLY")
			done <.oomer/.server_ips
			[[ $REPLY ]] && server_ip+=("$REPLY")
			last_used=${server_ip[$(( ${#server_ip[@]} - 1)) ]}
			server_count=$(( ${#server_ip[@]} + 1))
			server_name_default="server${server_count}"
			IFS='.' read -ra octet <<< "$last_used"
			octet0=${octet[0]}
			octet1=${octet[1]}
			octet2=${octet[2]}
			octet3=${octet[3]}
			((octet3++))
			if [[ octet3 -eq 255 ]]; then
				echo "only 254 servers are supported 10.87.1.1-10.87.1.254"
				echo "you are on your own in editing this script"
				exit
			fi

		fi

		# only server and people can be renamed, making the .oomer credentials to be human readable
		# lighthouses will be hardcode lighthouse1...
		while :
		do
			echo -e "\nEnter server name ..."
			read -p "default ( $server_name_default ): " server_name
			if [ -z $server_name ]; then
				server_name=$server_name_default
			fi
			if [ -z $(grep $server_name .oomer/.server_names) ]; then
				break	
			else
				echo "${server_name} name already exists, try again"
			fi
		done

		if test -f ".oomer/server/${server_name}/${server_name}.key"; then
			echo -e ".oomer/server/${server_name}${server_name}.key exists, skipping"
		else
			mkdir -p  ".oomer/server/${server_name}"
			echo .oomer/bin/nebula-cert sign -name ${server_name} -ip ${octet0}.${octet1}.${octet2}.${octet3}/${mask} -groups "oomer,server" -out-crt ".oomer/server/${server_name}/${server_name}.crt" -out-key ".oomer/server/${server_name}/${server_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"
			.oomer/bin/nebula-cert sign -name ${server_name} -ip ${octet0}.${octet1}.${octet2}.${octet3}/${mask} -groups "oomer,server" -out-crt ".oomer/server/${server_name}/${server_name}.crt" -out-key ".oomer/server/${server_name}/${server_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"
			cp .oomer/keyauthority/ca.crt .oomer/server/${server_name}
			echo ${octet0}.${octet1}.${octet2}.${octet3} > .oomer/server/${server_name}/.nebula_ip

			# Need to cd to get proper relative paths for tar
			origdir=$(pwd)
			# stash used ips
			echo "${octet0}.${octet1}.${octet2}.${octet3}" >> .oomer/.server_ips
			echo "$server_name" >> .oomer/.server_names
			if test -d .oomer/server; then
				cd .oomer/server
				find "${server_name}" -type f -exec tar -rvf temp.tar {} \;
				echo openssl enc -aes-256-cbc -salt -pbkdf2 -in "temp.tar" -out $origdir/.oomer/keysencrypted/${server_name}.keys.encrypted -pass stdin <<< "$encryption_passphrase"
				openssl enc -aes-256-cbc -salt -pbkdf2 -in "temp.tar" -out $origdir/.oomer/keysencrypted/${server_name}.keys.encrypted -pass stdin <<< "$encryption_passphrase"
				rm temp.tar
				cd $origdir
			else
				echo "FAIL: Something is wrong with .oomer/server"
			fi
		fi

	fi


	# worker keys are a novel store of credentials specifically for a renderfarm
	# normal render nodes would use automation scripts to spin up a cloud instance and assign keys
	# while this provides the best security, it adds complexity to spinning up resources
	# requiring tracking deployed keys
	# worker keys assert that they are secure as a group, not as an individual node
	# if the system is compromised, then the group should be revoked
	# this approach means that unlike server, lighthouse, and personal nebula nodes, workers do not
	# carry a unique provate key, rather they carry ALL worker keys 
	# nebula's systemd unit dynamically chooses a private key based on HOSTNAME
	# this simplification allows the end-user to create 2 undesirable situations
	# 1. Naming instance wrongname0001 with no corresponding /etc/nebula/wrongname0001.key
	# 2. Naming 2 instances with the same name worker0001 and worker0001, leading to nebula failure

	if [[ ${new_key_type} == "worker" ]] || [[ ${new_key_type} == "oomerfarm" ]] ; then
		workernum_default=10
		workernum=$workernum_default
		if ! [[ ${new_key_type} == "oomerfarm" ]] ; then
			echo -e "/nAdd additional workers ..."
			read -p "default ( $workernum_default ): " workernum
			if [ -z $workernum ]; then
				workernum=$workernum_default
			fi
		fi

		worker_prefix="worker"

		if ! test -f .oomer/.worker_ips; then
			octet2=99
			octet3=1
		else
			# read text list of used ips
			unset -v worker_ip
			while IFS= read -r; do
				worker_ip+=("$REPLY")
			done <.oomer/.worker_ips
			[[ $REPLY ]] && worker_ip+=("$REPLY")
			last_used=${worker_ip[$(( ${#worker_ip[@]} - 1)) ]}
			echo "last used$last_used"
			worker_last_count=$(( ${#worker_ip[@]} + 1))
			echo "worker_last_count$worker_last_count"
			IFS='.' read -ra octet <<< "$last_used"
			octet0=${octet[0]}
			octet1=${octet[1]}
			octet2=${octet[2]}
			octet3=${octet[3]}
			((octet3++))
			if [[ octet3 -eq 255 ]]; then
				((octet2++))
				octet3=1
				if [[ octet2 -eq 255 ]]; then
					echo "only a subnet mask of 16 is supported"
					echo "you have exceed number of workers supported"
					echo "you are on your own in editing this script"
					exit
				fi
			fi

		fi

		mkdir -p .oomer/worker

		# Create multiple worker keys
		# ===========================
		for ((count = 1 ; count <= "${workernum}" ; count++)); do
			worker_count=$(($worker_last_count + $count))
			worker_padded=$(printf %04d $worker_count)
			.oomer/bin/nebula-cert sign -name "${worker_prefix}${worker_padded}" -ip "${octet0}.${octet1}.${octet2}.${octet3}/${mask}" -groups "oomer" -out-crt ".oomer/worker/${worker_prefix}${worker_padded}.crt" -out-key ".oomer/worker/${worker_prefix}${worker_padded}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key" 
			echo "${octet0}.${octet1}.${octet2}.${octet3}" >> .oomer/.worker_ips
			
			# get next unique worker nebula ip
			((octet3++))
			if [[ octet3 -eq 255 ]]; then
				((octet2++))
				octet3=1
				if [[ octet2 -eq 255 ]]; then
					((octet1++))
					## WARNING you are probably making too many certificates if you get here
					if [[ octet1 -eq 255 ]]; then
						((octet0++))
						if [[ octet0 -eq 255 ]]; then
							break
						fi
					fi
				fi
			fi
		done

		cp .oomer/keyauthority/ca.crt ".oomer/worker"
		origdir=$(pwd)
		if test -d .oomer/worker; then
			cd .oomer/worker
			find "." -type f -exec tar -rvf temp.tar {} \;
			openssl enc -aes-256-cbc -salt -pbkdf2 -in "temp.tar" -out ${origdir}/.oomer/keysencrypted/worker.keys.encrypted -pass stdin <<< "$encryption_passphrase" 
			rm temp.tar
			cd $origdir
		fi
	fi


	# user keys are different than servers, lighthouse and workers which are semi-autonomous linux members of the vpn
	# user keys are used on desktop/laptop computers

	if [[ ${new_key_type} == "user" ]]; then
		# [ TODO ] standard users and admins
		# worker nodes and server nodes cannot ssh to user nodes

		if ! test -f .oomer/.user_ips; then
			octet2=10
			octet3=1
			user_name_default="person1"
		else
			# read text list of used ips
			unset -v user_ip
			while IFS= read -r; do
				user_ip+=("$REPLY")
			done <.oomer/.user_ips
			[[ $REPLY ]] && user_ip+=("$REPLY")
			last_used=${user_ip[$(( ${#user_ip[@]} - 1)) ]}
			user_count=$(( ${#user_ip[@]} + 1))
			user_name_default="user${user_count}"
			IFS='.' read -ra octet <<< "$last_used"
			octet0=${octet[0]}
			octet1=${octet[1]}
			octet2=${octet[2]}
			octet3=${octet[3]}
			((octet3++))
			if [[ octet3 -eq 255 ]]; then
				echo "only 254 user nodes are supported 10.87.1.1-10.87.1.254"
				echo "you are on your own in editing this script"
				exit
			fi
		fi

		# only server/user nodes can be renamed, making the keys easily human readable
		while :
		do
			echo -e "\nEnter user name ..."
			read -p "default ( $user_name_default ): " user_name
			if [ -z $user_name ]; then
				user_name=$user_name_default
			fi
			if ! test -d .oomer/user/$user_name; then
				break	
			else
				echo ".oomer/user/${user_name} name already exists, try again"
			fi
		done

		mkdir -p .oomer/user/${user_name} 
		echo .oomer/bin/nebula-cert sign -name "${user_name}" -ip "${octet0}.${octet1}.${octet2}.${octet3}/${mask}" -groups "oomer,server,person" -out-crt ".oomer/user/${user_name}/${user_name}.crt" -out-key ".oomer/user/${user_name}/${user_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"
		.oomer/bin/nebula-cert sign -name "${user_name}" -ip "${octet0}.${octet1}.${octet2}.${octet3}/${mask}" -groups "oomer,server,person" -out-crt ".oomer/user/${user_name}/${user_name}.crt" -out-key ".oomer/user/${user_name}/${user_name}.key" -ca-crt ".oomer/keyauthority/ca.crt" -ca-key ".oomer/keyauthority/ca.key"

		origdir=$(pwd)
		cp .oomer/keyauthority/ca.crt .oomer/user/${user_name}
		echo ${octet0}.${octet1}.${octet2}.${octet3} > .oomer/user/${user_name}/.nebula_ip
		echo ${octet0}.${octet1}.${octet2}.${octet3} >> .oomer/.user_ips
		echo ${user_name} >> .oomer/.user_names

		cd .oomer/user
		find "${user_name}" -type f -exec tar -rvf temp.tar {} \;
		echo openssl enc -aes-256-cbc -salt -pbkdf2 -in temp.tar -out $origdir/.oomer/keysencrypted/${user_name}.keys.encrypted -pass stdin <<< "$encryption_passphrase" 
		openssl enc -aes-256-cbc -salt -pbkdf2 -in temp.tar -out $origdir/.oomer/keysencrypted/${user_name}.keys.encrypted -pass stdin <<< "$encryption_passphrase" 
		rm temp.tar
		cd $origdir

	fi

	if [[ ${new_key_type} == "quit" ]]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			open .oomer/keysencrypted
		fi
		if [[ "$OSTYPE" == "msys"* ]]; then
			explorer .oomer\\keysencrypted
		fi
		exit
	fi

done
