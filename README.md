# oomerfarm: Simple bash scripts to deploy a personal renderfarm 

[ WORK IN PROGRESS ]
[ BETA release v0.4 ]

>A renderfarm takes a workload, distributes it over a network and provides these benefits.
  1. Frees up desktop/laptop cpu
  2. Wedge testing simplified with queueing
  3. As needed **cloud computers** scale to:
      - Reduce render time
      - Reduce capital costs via hourly rentals

![image](./img/Monitor.png )

- oomerfarm is bootstrapped by running bash scripts after connecting with [ssh]( Documentation/ssh.md ) to most cloud vendors. 

- bash scripts can also run natively on MacOS and Linux and on Windows with [help](https://git-scm.com) , making them cross platform.

- A renderfarm is complicated ..  so simple, in this context, just means wrapping up this complexity by having you systematically run scripts in a certain order. 

### run scripts ... render images  ###

1. run ***bootstraphub.sh***  on a ***Linux computer***, it becomes a private ***hub*** server to queue render jobs.

![image](img/bootstraphub.svg)

2. run ***bridgeoomerfarm.sh*** on a ***desktop/laptop***,  to connect to your private oomerfarm. Submit jobs using this software https://awsthinkbox.com 

3. Spin up some fast cloud computers and run ***bootstrapworker.sh*** on each to get the renderfarm churning. Here is a [timelapse](https://a4g4.c14.e2-1.dev/public/oomerfarm/Googlet2d-standard-60x3-timelapse.mp4) at 2x speed, spinning up 3 Google instances. In real time it took 5 minutes per instances. 

4. When your ready for a permanent oomerfarm, run ***becomesecure.sh*** on your desktop/laptop to create create bespoke private keys to secure your castle.

5. So there you go: 4 bash scripts, all starting with the letter ***b*** to empower your personal renderfarm.
    - bootstraphub.sh
    - bootstrapworker.sh
    - bridgeoomerfarm.sh
    - becomesecure.sh

6. Click image to view 40 frames animation ( one hour on the Google renderfarm )

[![orange-juice.mp4](img/orange-juice00001.png)](https://a4g4.c14.e2-1.dev/public/bella/onehourorange-juiceturntable.mp4)
<sup>Sample scene from https://bellarender.com</sup>


---

# Guides

[Guide for a test drive renderfarm](Documentation/TestDrive.md)

[Guide for a personal renderfarm](Documentation/BespokeRenderfarm.md)

[Deadline Manual](https://docs.thinkboxsoftware.com/products/deadline/10.3/1_User%20Manual/manual/overview.html)

[FAQ](Documentation/FAQ.md)

# Notes

bootstraphub.sh only works on AlmaLinux 8.x/ RockyLinux 8.x and probably works on RHEL 8.x.

bootstrapworker.sh only works on AlmaLinux 8.x/ RockyLinux 8.x and probably works on RHEL 8.x. There is preliminary, not very well tested support for Ubuntu.




