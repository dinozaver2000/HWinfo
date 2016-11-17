#!/bin/bash
# Create report file and write date UUID and hostname 
echo "Checking Hardware " > /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo "[code]" >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo $(hostname)" " $(date) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
sudo dmidecode | grep 'UUID' >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# Model
(echo "Model: "  && sudo dmidecode -t system | grep -A 2 'Manufacturer') >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# Add CPU info to report
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
(echo "CPU:" && sudo lscpu ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 

# Memory
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
(echo "Memory and Swap:" && sudo dmidecode -t memory | egrep " MB| GB") >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
 sudo free >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log


#Network
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
(echo "Network:" && sudo lspci | egrep -i --color 'network|ethernet') >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# Hard Disks 
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
(echo "Hard Disks:" &&  sudo lsblk) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
echo "Storage info:" >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
df -hP >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo " " >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
sudo blkid >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# RHEL version
echo " " >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
(echo "RHEL version:" && cat /etc/redhat-release ; lsb_release -a ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 

# Architecture (has to be 64bits)
(echo "Architecture " && uname -m ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# Ensure there is no LVM
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
(echo "Ensure there is no LVM " && sudo lvmdiskscan ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

# RHEL subscription
echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 
(echo " RHEL subscription " && subscription-manager list ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
(echo -en "running rhn_check... exit code: " ; rhn_check >& /dev/null ; echo $? ) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log

echo ""  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log 

# Analize the manufacturer and run different tools depending of hardware:
MODEL=$(sudo dmidecode -t system | grep 'Manufacturer:' | awk '{print $2}')

printf "\033c"
# Run this only on VM's 
if [[ $MODEL == *"VMware"* ]]
then
	# Check if VMWARE TOOLS are installed
 	if
		! rpm -qa |grep -qw open-vm-tools 
		then
			sudo yum install -y open-vm-tools
	fi
	(echo "CPU Reserve:" && sudo vmware-toolbox-cmd stat cpures) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
	(echo "Memory Reserve:" && sudo vmware-toolbox-cmd stat memres) >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
fi

# Run this only on Dell
if [[ $MODEL == *"Dell"* ]]
then
	echo "Dell hardware detected checking if dell utils are installed"
	# check if srvadmin-all package is installed
	if ! rpm -qa | grep -qw srvadmin-all; 
		then	# try to install dell tools:
			# Setup the repo
			sudo yum install wget && sudo wget -q -O - http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi | bash
			# Install tools:
			sudo yum install srvadmin-all
	fi	
	# run omreport
                sudo $(which omreport) chassis remoteaccess >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which omreport) storage controller >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
#                sudo $(which omreport) storage pdisk controller=1 | grep ^Capacity >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which omreport) chassis pwrsupplies >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which omreport) storage vdisk >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which omreport) storage battery >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
		for i in $(echo $(omreport storage controller | grep ^ID | awk '{print $3}')) ; do  omreport storage pdisk controller=$i; done | grep -v 'Name\|Status\|Bus\|Cache\|Remaining\|Failure\|Revision\|Driver\|Model\|T10\|Cretified \|Available\|Applicable\|Vendor\|Product\|Serial\|Part\|Sector\|Encryption\|Address'  >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
fi

# Run this only on HP
if [[ $MODEL == *"HP"* ]]
then
	echo "HP hardware detected checking if HP utils are installed"
	# check if HP tools are installed
	if ! rpm -qa | grep -qw hpssacli;
        	then    # Install HP tools
		sudo rpm --import http://downloads.linux.hpe.com/SDR/hpPublicKey1024.pub && \
		sudo rpm --import http://downloads.linux.hpe.com/SDR/hpPublicKey2048.pub && \
		sudo rpm --import http://downloads.linux.hpe.com/SDR/hpPublicKey2048_key1.pub
		sudo echo '[hp]' > /etc/yum.repos.d/hp.repo
		sudo echo 'name=HP Proliant Red Hat Enterprise Linux $releasever - $basearch' >> /etc/yum.repos.d/hp.repo
		sudo echo 'baseurl=http://downloads.linux.hpe.com/SDR/downloads/ServicePackforProLiant/RedHat/$releasever/$basearch/current/' >> /etc/yum.repos.d/hp.repo
		sudo echo "enabled=1" >> /etc/yum.repos.d/hp.repo
		sudo echo "gpgcheck=1" >> /etc/yum.repos.d/hp.repo
		sudo echo "gpgkey=http://downloads.linux.hpe.com/SDR/downloads/ServicePackforProLiant/GPG-KEY-ProLiantSupportPack" >> /etc/yum.repos.d/hp.repo
		sudo echo "" >> /etc/yum.repos.d/hp.repo

		sudo yum install -y hpvca hp-health hp-smh-templates hp-ams hponcfg hpsmh hpssacli hp-fc-enablement hp-snmp-agents hpdiags lm_sensors-libs net-snmp-libs net-snmp redhat-rpm-config kernel-headers kernel-devel rpm-build gcc expect glibc libuuid freetype.x86_64 compat-glibc compat-glibc lm_sensors-libs net-snmp-libs.x86_64 libSM.x86_64 libXi.x86_64 libXrender.x86_64 libXrandr.x86_64 libXfixes.x86_64 libXcursor.x86_64 fontconfig.x86_64 expat.x86_64 zlib.x86_64 libstdc++.x86_64

	fi
		sudo $(which hpasmcli) -s 'show SERVER' | grep ^System >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
		sudo $(which hpasmcli) -s 'show DIMM' >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
		sudo $(which hpasmcli) -s 'show POWERSUPPLY' >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which hpssacli) ctrl all show >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
                sudo $(which hpssacli) ctrl all show config >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
fi
echo "[/code]" >> /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log
# Display the collected info and ask for confirmation to send the file
echo "************************************************************************"
echo "$(cat /tmp/hwcheck_$(hostname)$(date +"%Y%m%d").log)"
echo "************************************************************************"
echo ""


