# oomerfarm: Simple bash scripts to deploy a personal renderfarm 

[ DO NOT USE IN PRODUCTION -- WORK IN PROGRESS ]
[ ALPHA release v0.3 , only for the technically curious]

![image](./img/Monitor.png )

- A renderfarm is complicated ..  so simple, in this context, just means wrapping up this complexity by having you systematically run scripts in a certain order. 

- oomerfarm is comprised of 4 scripts run on the command line ( there is no GUI ). This simple script approach allows oomerfarm render nodes to work on Azure, Google, AWS, etc so you can shop for the best hourly price. It also allows the desktop/laptop scripts to run natively on MacOS and Linux and on Windows with [help](https://git-scm.com)

- As an example, this Bella path tracer sample scene [orange-juice-turntable.mp4](https://a4g4.c14.e2-1.dev/public/bella/onehourorange-juiceturntable.mp4) rendered on Google's Cloud in one hour using 3 x 60 core t2d-standard-60 spot instances at $0.47/hr/instance. Setup of each worker took about 5 minutes while the hub server was previously setup on a low-end machine running 24/7. 

### run scripts ... render images  ###

1. run ***one*** script on a ***Linux computer***, it becomes a private ***hub*** server to queue render jobs.

![image](img/bootstraphub.svg)

2. run ***one*** script on a ***desktop/laptop***,  to connect to your private oomerfarm. Submit jobs using this software https://awsthinkbox.com 

3. Spin up some fast cloud computers and run ***one*** script on each to get the renderfarm churning. Here is a [timelapse](https://a4g4.c14.e2-1.dev/public/oomerfarm/Googlet2d-standard-60x3-timelapse.mp4) at 2x speed, starting up 3 Google cloud computers and running bootstrapworker.sh.

4. Click image to view 40 frame animation renderered after one hour

[![orange-juice.mp4](img/orange-juice00001.png)](https://a4g4.c14.e2-1.dev/public/bella/onehourorange-juiceturntable.mp4)
<sup>Sample scene from https://bellarender.com</sup>


---

>A renderfarm takes a workload, distributes it over a network and provides these benefits.
  1. Frees up desktop/laptop cpu
  2. Wedge testing simplified with queueing
  3. As needed **cloud computers** scale to:

        Reduce render time

        Reduce capital costs via hourly rentals

# Guides

[Guide for a test drive renderfarm](Documentation/TestDrive.md)

[Guide for a personal renderfarm](Documentation/BespokeRenderfarm.md)






