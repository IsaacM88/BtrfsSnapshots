# BtrfsSnapshots
This bash script creates and deletes Btrfs subvolume snapshots on a schedule using Cron. Errors will appear throught Gnome's notification system. This was tested on Fedora Workstation 37.

Install and enable Cronie if you don’t already have it.
```
sudo dnf install cronie
sudo systemctl status crond.service
sudo systemctl enable crond.service
sudo systemctl start crond.service
```
Create a snapshots subvolume to store your snapshots.
```
sudo btrfs subvolume create /snapshots
```
Copy the “home” line is fstab and change both occurrences of “home” to “snapshots” so the snapshots subvolume will mount when the computer starts.
```
sudo vi /etc/fstab
```
Live boot Fedora from a USB drive. Decrypt and mount your file system using Gnome Disks. Move the snapshots directory to the top level.
```
sudo mv /run/media/liveuser/fedora_localhost-live/root/snapshots /run/media/liveuser/fedora_localhost-live/snapshots
```
Reboot into your Fedora installation and verify /snapshots/ is a top level (5) subvolume.
```
sudo btrfs subvolume list / -at
```
Edit snapshot.sh and change the user defined variables.
Have Cron run snapshot.sh on a schedule.
```
sudo vi /etc/crontab
  42  *  *  *  * root       bash /home/sudoer/Documents/snapshot.sh
```
View job log and check /snapshots/ to make sure it is working properly.
```
journalctl -u crond.service
```
