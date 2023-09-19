# oomerfarm

[ DO NOT USE IN PRODUCTION -- WORK IN PROGRESS ]

# oomerfarm is a personal Bella renderfarm deployed using simple bash scripts and Google Drive

#### Reduce the complex interdependent relationships of networking, security, database serving, certificate-signing, bella render plugins, smb windows file sharing in these steps.

Deploy hub

Create local stufff

Send a job

Deploy workers





consisting of:
-  a **hub** host running Alma/Rocky Linux 8.x, Samba, MongoDB in the cloud
- an enterprise grade overlay network https://github.com/slackhq/nebula
- **worker** hosts for simultaneoulsy Bella rendering locally AND/OR in cloud
- **boss** hosts for submitting jobs and admin

- connection and certificate signing scripts generic enough to run on Linux and MacOS without additonal runtimes like Python.
- connection and certificate signing scripts can run on Windows with msys ( tested with https://git-scm.com )

TODO:
- MongoDB security is over unsecure http but within secure VPN, add openssl certs to secure against  man-in-the-VPN-middle attacks