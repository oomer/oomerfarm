# oomerfarm: Simple bash scripts to deploy a personal renderfarm 

[ WORK IN PROGRESS ]
[ BETA release v0.6 ]


>oomerfarm deploys a Deadline renderfarm in about 20 minutes including a VPN to make networking secure for a lone artist. 

## Renderfarm benefits 
A renderfarm takes a workload, distributes it over a network and provides: 
  1. freedom to continue working on your computer by dispatching cpu intensive workloads to the "farm"
  2. a GUI to track job submissions, success, progress and failures.
  3. Perform post-render operations like convert frames to video or merge co-operative renders. 

![image](./img/Monitor.png )

## oomerfarm benefits
- The network topology of the included VPN, allows working from home or the coffee shop.
- The same topology avoids lock-in to any particular cloud computer vendor allowing you to shop for the best hourly rates.
- A renderfarm is complicated and oomerfarm doesn't make it simpler but it does wraps up this complexity by boiling it down to 4 bash scripts

---
## Required Equipment 
- Computer A => **MacOS** or **Windows** 
- Computer B => a **Linux** 24/7 server: 
    - Doesn't render, just runs file server and dispatches jobs
    - [RECOMMENDED] run a a cheap $5/mth server 
    - OR run on a mini pc at home and port forward [42042] on your router 
- Computer C-Z => cpu or gpu heavy Linux machines: 
    - [RECOMMENDED] rent hourly computers like [these](https://vultr.com/)
    - OR Add your own computers 
---

## Run scripts

1. ***bash becomesecure.sh*** in your Desktop/Laptop terminal to create bespoke VPN credentials  ( Win users need https://git-scm.com)
2. Put encrypted keys on Google Drive and share publicly
3. ***bash bootstraphub.sh*** on Computer B
    - ***Alma/Rocky 8.x 9.x Linux [Recommened]***
    - Ubuntu 20.04 or 22.04
    - this becomes your centralized **Deadline renderfarm** hub with:
        - file server to save scenes and textures
        - render queue database
        - virtual private network

4. ***bash bridgeoomerfarm.sh*** on Desktop/Laptop  connects to hub
    - Install Deadline 10.4.0.10 client software https://awsthinkbox.com for renderfarm GUI 
5. Rent **cloud** computers and run ***bash bootstrapworker.sh***. Here is a [timelapse](https://a4g4.c14.e2-1.dev/public/oomerfarm/Googlet2d-standard-60x3-timelapse.mp4) at 2x speed, spinning up 3 Google instances. 

## Summary

5. Four bash scripts, all starting with the letter ***b*** to empower your personal renderfarm.
    - becomesecure.sh
    - bootstraphub.sh
    - bootstrapworker.sh
    - bridgeoomerfarm.sh

---

## Step by step guides

[Guide for a test drive renderfarm](Documentation/TestDrive.md)

[Guide for a personal renderfarm](Documentation/BespokeRenderfarm.md)

[Deadline Manual](https://docs.thinkboxsoftware.com/products/deadline/10.3/1_User%20Manual/manual/overview.html)

[FAQ](Documentation/FAQ.md)