# HWinfo
BASH scripts to get the information about RHEL (and family) server hardware (HP, Dell, VMWARE)
collectHWInfo.sh is a bash script which uses linux dmidecode, lscpu, free, lspci, lsblk, blkid, uname, lvmdiskscan, and some other vendor specific tools to collect a report about server hardware, storage config and RHN subscription in a /tmp/hwcheck_____ file. 
