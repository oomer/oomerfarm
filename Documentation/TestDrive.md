### Test Drive

 📘 A renderfarm is very complex, this guide is a paint-by-numbers approach for a first time user.

- Notably, by using not-so-secret keys, connecting to the oomerfarm VPN is simplified. These keys allow intrusion without your knowledge but only if an unwanted guest knows your hub's internet address. Use only for short periods of time and switch to [bespoke keys](BespokeRenderfarm.md) when ready


### For storing scenes and textures, setup a Linux file server and render manager.

<sup>[hub]</sup> Spin up a cloud computer with Alma/Rocky 8.x Linux or get Linux on an old computer<sup>1 core is enough</sup>

```sh
sudo dnf -y install git
git clone -b "v0.4" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstraphub.sh
```

## For rendering work, setup one or more Linux machines

<sup>[worker(s)]</sup> Rent 1+ servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git
git clone -b "v0.4" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstrapworker.sh
```

## Submit a job from desktop/laptop
#### Connect to private oomerfarm VPN
- From Linux/MacOS shell or [ git-bash ]( https://git-scm.com )<sup>Win</sup>
```sh
git clone "v0.4" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
bash bridgeoomerfarm.sh
```
* On Windows, right-click bridgeoomerfarm.bat, run as administrator

#### Mount network folders

- ***Finder:*** ( smb://hub.oomer.org )
- ***Explorer:*** ( \\\\hub.oomer.org )

    - mount ***DeadineRepository10*** and ***oomerfarm***
    - [user] ***oomerfarm***
    - [password] ***oomerfarm***

#### Install Deadline 10.3.0.13 Client software
- Follow [Win GUI guide](GuiDeadlineClientInstallWindows.md)
- Follow [MacOS GUI guide](GuiDeadlineClientInstallMacOS.md)
- Optionally [Win CLI guide](CliDeadlineClientInstallWindows.md)
- Optionally [MacOS CLI guide](CliDeadlineClientInstallMacOS.md)

#### Submit orange-juice.bsz job
- Run Deadline Monitor, **Menu**->**Submission**->**BellaRender**
- Set render scene to ***oomerfarm/bella/orange-juice.bsz***
- Set render output dir to ***oomerfarm/bella/renders*** folder
- Click ***Submit***