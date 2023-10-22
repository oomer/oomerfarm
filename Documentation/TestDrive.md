### Test Drive

 📘 A renderfarm is very complex, these steps guide a first time user like falling down a water slide. 

- Notably, by using not-so-secret keys, connecting to the oomerfarm VPN is simplified. These keys allow intrusion without your knowledge but only if an unwanted guest knows your hub's internet address. Use only for short periods of time and switch to [bespoke keys](BespokeRenderfarm.md) when ready

1. <sup>[hub]</sup> Rent AlmaLinux 8.x or get Linux on an old computer<sup>1 core is enough</sup>

```sh
sudo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstraphub.sh
```
2. <sup>[worker(s)]</sup> Rent 1+ servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstrapworker.sh
```

3. <sup>[boss]</sup> on Desktop Linux/MacOS shell or [ git-bash ]( https://git-scm.com )<sup>Win</sup>
```sh
git clone "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
bash joinoomerfarm.sh
* On Windows run joinoomerfarm.bat as administrator
```

   - Mount<sup>win/mac/linux</sup> DeadlineRepositry10<sup>share</sup> from hub.oomer.org
    - Mount<sup>win/mac/linux</sup> oomerfarm<sup>share</sup> from hub.oomer.org
        - [user] ***oomerfarm***
        - [password] ***oomerfarm***
   - Start DeadlineMonitor
    - Select BellaRender 
        - pick orange-juice.bsz on oomerfarm<sup>share</sup>
        - pick output directory on oomerfarm<sup>share</sup>
        - submit job
        - monitor job
        - copy rendered images locally from oomerfarm<sup>share</sup>
- Terminate any rented hubs + workers to avoid any further hourly charges. Done!