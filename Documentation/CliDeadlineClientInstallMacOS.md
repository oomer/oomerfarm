### MacOS CLI install ( avoids ambiguity when using GUI installer )

```sh
curl -O https://thinkbox-installers.s3.us-west-2.amazonaws.com/Releases/Deadline/10.3/4_10.3.0.15/Deadline-10.3.0.15-osx-installers.dmg

hdiutil attach Deadline-10.3.0.15-osx-installers.dmg

cd /Volumes/Deadline-10.3.0.15-osx-installers

sudo ./DeadlineClient-10.3.0.15-osx-installer.app/Contents/MacOS/osx-x86_64 --mode unattended --connectiontype Direct --repositorydir //Volumes/DeadlineRepository10 --slavestartup false --unattendedmodeui minimal
```