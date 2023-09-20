# oomerfarm

[ DO NOT USE IN PRODUCTION -- WORK IN PROGRESS ]
[ Windows and Linux desktop not tested yet , it may work ]
[ Bella plugins not integrated yet ]
[ No bootstrapworker.sh yet ]
[ No local hub install yet ]
[ security model under review ]
# *oomerfarm:* an occasional renderfarm deployed using simple bash scripts and Google Drive 

#### Navigate the complex render manager interdependencies between networking, database server, certificate-signing, secrets management and file sharing allowing you to:

- Spin up a weekend renderfarm on Friday and tear it all down on Sunday.
- Install AWS Thinkbox's Deadline and get all the the benefits of a studio grade render manger.
- Connect to a cloud file server to save textures and scene files and to download rendered frames.
- Use vms from Google Cloud, AWS, Azure simultaneously or dump those guys and book an all-expenses-included monthly provider like https://crunchbits.com ( not a paid schill, I just love them )

> 📘 10 Steps for the weekend render warrior!
>
>1. Buy a cloud server for an hour, week or a year and install AlmaLinux 8.x or RockLinux 8.x, [[ ***keyoomerfarm.sh*** will request IPv4 internet address of this machine]]
>> - or use an old computer in the basement 
>2. Install **git** on personal computer. Execute these lines natively on Linux/MacOS and via Windows bash if https://git-scm.com is installed.
>```sh
>git clone https://github.com/oomer/oomerfarm.git
>cd oomerfarm 
>bash keyoomerfarm.sh
>```
>
>3. Open folder oomerfarm/_oomerkeys_ . Open https://drive.google.com . Drag ***hub.keybundle.enc*** and ***workers.keybundle.enc*** to a Google Drive folder. Share using ***Anyone with link*** then click ***Copy Link***'. ***bootstraphub.sh*** will request this URL
>4. From personal computer ***ssh*** to server from step #1
>>> as root or as sudo user [ sudo bash ...]
>```sh
>git clone https://github.com/oomer/oomerfarm.git
>cd oomerfarm
>bash bootstraphub.sh
>```
>5. On personal computer
> - ( leave this window open to maintain VPN)
>```sh
>bash joinoomerfarm.sh
>```
>6. ***Finder:*** ( smb://10.10.0.1 )
***Explorer:*** ( \\\\10.10.0.1 )
> - mount shares ***DeadineRepository10*** and ***Bella***
> - [user] ***deadline***
> - [password] as requested by ***boostraphub.sh***
>7. Drag a Bella scene file (***.bzx***) to smb://10.10.0.1/Bella
>8. Run Deadline Client installer on personal computer from https://awsthinkbox.com
>9. Launch Deadline Monitor and submit job
>10. Wonder why nothing happens...Duh we forgot to spin up some workers. [ to be continued ]


## Tech breakdown:
-  a **hub** host running Alma/Rocky Linux 8.x, Samba, MongoDB and AWS Thinkbox's Deadline Repository in the cloud
- an enterprise grade built-in firewall overlay network https://github.com/slackhq/nebula ( open source with full certificate-authority infrastructure[ allowing you to skip third party CA's ] )
- Linux **worker** hosts for simultaneously rendering locally AND/OR in cloud. VPN IP address assignment is written to Nebula certs/keys by ***keyoomerfarm.sh***. Instead of a typical deploy new instance with a bespoke cert/key, ***oomerfarm*** adopts ***batch certification***, as I call it, meaning every worker stores ALL worker certs/keys and on boot dynamically chooses one. Thus any worker vm can be cloned via the cloud providers web panel or programmatically via cli tools.
- Because oomerfarm's bash scripts don't take very long to run, the network topology can be redefined by rerunning keyoomerfarm.sh and the new keybundles can be reuploaded to Google drive to seed the hub and a new batch of workers.
- Win/Mac/Linux **boss** hosts for submitting jobs
- certificate signing scripts generic enough to natively run on Linux and MacOS without additonal runtimes.
( Windows needs msys as in https://git-scm.com )

TODO:
- MongoDB security is over unsecure http but within secure VPN, should add openssl certs to secure against man-in-the-VPN-middle attacks