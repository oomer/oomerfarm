# oomerfarm

[ DO NOT USE IN PRODUCTION -- WORK IN PROGRESS ]
[ ALPHA release v0.3 , only for the technically curious]

### Simple bash scripts to deploy a personal renderfarm 

![image](./img/Monitor.png )

- A renderfarm is complicated ..  so simple, in this context, just means wrapping up this complexity by having you systematically run scripts in a certain order. 

- As an example this Bella path tracer sample scene [orange-juice-turntable.mp4](https://a4g4.c14.e2-1.dev/public/bella/onehourorange-juiceturntable.mp4) rendered on Google Cloud in one hour using 3 x 60 core t2d-standard-60 spot instances at $0.47/hr/instance. Starting 3 workers before the render took about 15 minutes while the hub server runs on a low-end machine that is on 24/7. My laptop submits animation job via the Deadline Monitor app.

- oomerfarm is comprised of 4 scripts run on the command line ( there is no GUI ). This simple script approach allows oomerfarm render nodes to work on Azure, Google, AWS, etc so you can shop for the best hourly price. It also allows the desktop/laptop scripts to run natively on MacOS and Linux and on Windows with [help](https:/git-scm.com)




### run scripts ... render images  ###

1. run ***one*** script on a ***Linux computer***, it becomes a private ***hub*** server to queue render jobs.

![image](img/bootstraphub.svg)

2. run ***one*** script on ***laptop***,  it connects to your private oomerfarm.  Mount two network folders, run Deadline Monitor from https://awsthinkbox.com to submit jobs.

3. Spin up some fast cloud computers and run ***one*** script on each to get the renderfarm churning.

---

>A renderfarm takes a workload, distributes it over a network and provides these benefits.
  1. Frees up desktop/laptop cpu
  2. Wedge testing simplified with queueing
  3. As needed **cloud computers** scale to:

        Reduce render time

        Reduce capital costs via hourly rentals





---

 📘 To test drive for a few hours

1. **Warning** The oomerfarm test drive uses public VPN certificates. This allows somebody who can access this github AND who knows the public ip address of your hub to connect to your VPN. Test drive only if you understand this security hole. 

2. <sup>[hub]</sup> Rent AlmaLinux 8.x or get Linux on an old computer<sup>1 core is enough</sup>

```sh
sduo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstraphub.sh
```
3. <sup>[worker(s)]</sup> Rent 1+ servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstrapworker.sh
```

4. <sup>[boss]</sup> on Desktop Linux/MacOS shell or [ git-bash ]( https://git-scm.com )<sup>Win</sup>
```sh
git clone "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
bash joinoomerfarm.sh
* On Windows run joinoomerfarm.bat as administrator
```
5. On desktop<sup>boss</sup>
    - Install [ Deadline ]( https://awsthinkbox.com )
```sh
curl -O https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/3_10.3.0.13/Deadline-10.3.0.13-windows-installers.zip

unzip Deadline-10.3.0.13-windows-installers.zip
```

Open a Powershell, as administrator

cd to oomerfarm directory ( same as git-bash above )
```sh
./DeadlineClient-10.3.0.13-windows-installer.exe --mode unattended --connectiontype Direct --repositorydir //hub.oomer.org/DeadlineRepository10 --slavestartup false --unattendedmodeui minimal
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

 📘 Steps for a long term personal renderfarm

1. On desktop<sup>boss</sup>

```sh
dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
bash keyoomerfarm.sh
```

2. Open folder oomerfarm/_oomerkeys_ . Put ***hub.keybundle.enc*** and ***workers.keybundle.enc*** on Google Drive. Share using ***Anyone with link*** then click ***Copy Link***'. 

3. <sup>[aka hub]</sup> Rent AlmaLinux 8.x or get Linux on an old computer<sup>1 core is enough</sup>

```sh
sudo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstraphub.sh
* instead of "i_agree_this_is_unsafe" use "hub"
* Use your google drive url to hub.keybundle.enc
```
4. <sup>[aka worker(s)]</sup> Rent 1+ servers with LOTSA<sup>TM</sup> cores

```sh
sudo dnf -y install git
git clone -b "v0.3" https://github.com/oomer/oomerfarm.git
cd oomerfarm 
sudo bash bootstrapworker.sh
* Use your google drive url to worker.keybundle.enc
* Use unique name required per worker ie worker0001, worker0002 
```
5. Back to desktop<sup>mac/linux</sup>
```sh
bash joinoomerfarm.sh
* Leave shell open to maintain VPN
---
* On Windows run joinoomerfarm.bat as administrator
```
6. ***Finder:*** ( smb://hub.oomer.org )
***Explorer:*** ( \\\\hub.oomer.org )
 - mount shares ***DeadineRepository10*** and ***oomerfarm***
 - [user] ***oomerfarm***
 - [password] ***oomerfarm***
7. Drag a Bella scene file (***.bzx***) to 
    - //hub.oomer.org/oomerfarm/bella <sup>windows</sup>
    - //Volumes/oomerfarm/bella <sup>mac</sup>
    - //mnt/oomerfarm/bella <sup>linux</sup>
8. Run [***Deadline Client***](https://awsthinkbox.com) installer on desktop<sup>win/mac/linux</sup>
9. Launch Deadline Monitor and submit job
10. Done!


