### Windows CLI install ( avoids ambiguity when using GUI installer )

From cmd, git-bash or powershell
```sh
curl -O https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/4_10.3.0.15/Deadline-10.3.0.15-windows-installers.zip

unzip Deadline-10.3.0.15-windows-installers.zip
```

Open powershell, as administrator

cd to oomerfarm directory ( same as command line above )
```sh
./DeadlineClient-10.3.0.15-windows-installer.exe --mode unattended --connectiontype Direct --repositorydir //hub.oomer.org/DeadlineRepository10 --slavestartup false --unattendedmodeui minimal
```