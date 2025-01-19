# Detailed oomerfarm guide

### Create VPN keys on trusted desktop/laptop

```sh
git clone https://github.com/oomer/oomerfarm.git
cd oomerfarm 
bash becomesecure.sh
```

From folder ***oomerfarm/\.oomer\/keysencrypted***   
- upload to Google Drive
    - ***hub.keys.encrypted***
    - ***worker.keys.encrypted*** 
- Share both using ***Anyone with link*** 
- Use ***Copy Link***, and paste when asked for URL in bootstraphub.sh and bootstrapworker.sh

### Setup Linux file server and render manager.

Spin up a $5/mth cloud computer with Alma/Rocky 8.x 9.x Linux or on an old computer<sup>1 core is enough</sup>

```sh
sudo dnf -y install git
git clone https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstraphub.sh
```
## Create render nodes

4. Rent 1+ cloud servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git
git clone https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstrapworker.sh
```
* assign **UNIQUE** id 1-9999 to each node
* Use your **Google Drive** url to worker.keys.encrypted

## Submit jobs from desktop/laptop

- From Linux/MacOS shell or [ git-bash ]( https://git-scm.com )<sup>Win</sup>
```sh
bash bridgeoomerfarm.sh
```
* On Windows, right-click bridgeoomerfarm.bat, run as administrator

#### Mount network folders ( aka Windows SMB shares)

- ***Finder:*** ( smb://hub.oomer.org )
- ***Explorer:*** ( \\\\hub.oomer.org )

    - mount ***DeadineRepository10*** and ***oomerfarm***
    - [user] ***oomerfarm***
    - [password] ***oomerfarm***
 > Note: The bridging runs inside a VPN so all networking is encrypted. Read up on Samba if you wish to change password   

#### Save assets to network folder
 
- Drag a Bella scene file (***.bzx***) to 
    - //hub.oomer.org/oomerfarm/bella <sup>windows</sup>
    - /Volumes/oomerfarm/bella <sup>mac</sup>
    - /mnt/oomerfarm/bella <sup>linux</sup>

#### Install Deadline 10.4.0.10 Client software
- [Download installer](https://awsthinkbox.com)
- Optionally [Win CLI guide](CliDeadlineClientInstallWindows.md)
- Optionally [MacOS CLI guide](CliDeadlineClientInstallMacOS.md)

#### Submit a job
- Launch Deadline Monitor, Menu->Submission->BellaRender 
