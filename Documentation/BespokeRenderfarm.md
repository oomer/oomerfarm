# Setting up a personal renderfarm for the long term 

- An ideal personal renderfarm is cheap to maintain when idle and scalable to extreme compute cpu/gpu resources when needed.


## For long term security, first create VPN keys on a trusted desktop or laptop

```sh
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git

cd oomerfarm 

bash keyoomerfarm.sh
```

From folder ***oomerfarm/\_oomerkeys\_/boss***   
- upload to Google Drive
    - ***hub.keybundle.enc***
    - ***workers.keybundle.enc*** 
- Share both using ***Anyone with link*** 
- Use ***Copy Link***, and paste when asked for URL in bootstraphub.sh and bootstrapworker.sh

### For storing scenes and textures, setup a Linux file server and render manager.

While a **hub** server can be spun up as needed, just like **workers**, the **hub**'s compute resources needed are minimal that running it 24/7 is a low cost option.

<sup>[hub]</sup> Spin up a cloud computer with Alma/Rocky 8.x Linux or get Linux on an old computer<sup>1 core is enough</sup>

```sh
sudo dnf -y install git

git clone -b "v0.4" https://github.com/oomer/oomerfarm.git

cd oomerfarm 

sudo bash bootstraphub.sh
```
* instead of "i_agree_this_is_unsafe" type "hub"
* Use google drive URL to hub.keybundle.enc

## For rendering work, setup one or more Linux machines

4. <sup>[worker(s)]</sup> Rent 1+ servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git

git clone -b "v0.4" https://github.com/oomer/oomerfarm.git

cd oomerfarm 

sudo bash bootstrapworker.sh
```
* instead of "i_agree_this_is_unsafe" type "hub"
* Use your google drive url to worker.keybundle.enc
* assign unique id 1-9999 to each node

## Submit jobs from desktop/laptop

#### Connect to private oomerfarm VPN

- From Linux/MacOS shell or [ git-bash ]( https://git-scm.com )<sup>Win</sup>
```sh
bash bridgeoomerfarm.sh
```
* On Windows, right-click bridgeoomerfarm.bat, run as administrator

#### Mount network folders

- ***Finder:*** ( smb://hub.oomer.org )
- ***Explorer:*** ( \\\\hub.oomer.org )

    - mount ***DeadineRepository10*** and ***oomerfarm***
    - [user] ***oomerfarm***
    - [password] ***oomerfarm***

#### Save assets to network folder
 
- Drag a Bella scene file (***.bzx***) to 
    - //hub.oomer.org/oomerfarm/bella <sup>windows</sup>
    - /Volumes/oomerfarm/bella <sup>mac</sup>
    - /mnt/oomerfarm/bella <sup>linux</sup>

#### Install Deadline 10.3.0.15 Client software
- [Download installer](https://awsthinkbox.com)
- Optionally [Win CLI guide](CliDeadlineClientInstallWindows.md)
- Optionally [MacOS CLI guide](CliDeadlineClientInstallMacOS.md)

#### Submit a job
- Launch Deadline Monitor, Menu->Submission->BellaRender 