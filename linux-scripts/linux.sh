#!/bin/bash

# Using code from the following projects
# github.com/mike-bailey/CCDC-Scripts

# args: function user.file password.file
op=$1
users=$2
password=$3

change_pass () {
	while read user; do
		echo -e "$2\n$2\n" | sudo passwd $user > /dev/null 2>&1
		echo "Passwords changed!"
	done < $1
}

add_users() {
	echo "Added users!"
}

# Update hardening settings
harden_system() {
	if [[ $EUID -ne 0 ]]; then
   		echo "This script must be run as root"
  		exit 1
	fi
	
	# /etc/hosts file
	if [ -s /etc/hosts ]; then
	echo "Clearing HOSTS file"
		echo $(hostname) localhost > /etc/hosts
		echo 127.0.0.1	localhost >> /etc/hosts
		echo ::1     ip6-localhost ip6-loopback >> /etc/hosts
		echo fe00::0 ip6-localnet >> /etc/hosts
		echo ff00::0 ip6-mcastprefix >> /etc/hosts
		echo ff02::1 ip6-allnodes >> /etc/hosts
		echo ff02::2 ip6-allrouters >> /etc/hosts
	fi

	# SSH Server Configuration
	cat /etc/ssh/sshd_config | grep PermitRootLogin | grep yes
	if [ $?==0 ]; then
    	sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	fi

	cat /etc/ssh/sshd_config | grep Protocol | grep 1
	if [ $?==0 ]; then
    	sed -i 's/Protocol 2,1/Protocol 2/g' /etc/ssh/sshd_config
        sed -i 's/Protocol 1,2/Protocol 2/g' /etc/ssh/sshd_config
	fi

	grep X11Forwarding /etc/ssh/sshd_config | grep yes
	if [ $?==0 ]; then
    	sed -i 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
		break>> /dev/null
	fi

	# Sudoers - require password
	grep PermitEmptyPasswords /etc/ssh/sshd_config | grep yes
	if [ $?==0 ]; then
    	sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
	fi

	grep NOPASSWD /etc/sudoers
	if [ $?==0 ]; then
        EX=$(grep NOPASSWD /etc/sudoers)
		sed -i 's/$EX/ /g' /etc/sudoers
	fi

	# Remove extra sudoers files if exists
	mkdir /tmp/sudoers.bak
	ls /etc/sudoers.d | grep -v "ccsclient_sudoers README" | xargs -I {} mv /tmp/sudoers.bak

	#TODO Add install process for libpam-cracklib
	echo "Make sure libpam-cracklib is installed!"
	apt-get install libpam-cracklib -y &> /dev/null
	
	# Only allow root in cron
	cd /etc/
	/bin/rm -f cron.deny at.deny
	echo root >cron.allow
	echo root >at.allow
	/bin/chown root:root cron.allow at.allow
	/bin/chmod 400 cron.allow at.allow

	if [ "$?" -eq "1" ]; then	
		echo "auth optional pam_tally.so deny=5 unlock_time=900 onerr=fail audit even_deny_root_account silent" >> /etc/pam.d/common-auth
		echo "password requisite pam_cracklib.so retry=3 minlen=8 difok=3 reject_username minclass=3 maxrepeat=2 dcredit=1 ucredit=1 lcredit=1 ocredit=1" >> /etc/pam.d/common-password
		echo "password requisite pam_pwhistory.so use_authtok remember=24 enforce_for_root" >>  /etc/pam.d/common-password
	fi

	
	OLDFILE=/etc/login.defs
	NEWFILE=/etc/login.defs.new
	
	PASS_MAX_DAYS=15
	PASS_MIN_DAYS=6
	PASS_MIN_LEN=8
	PASS_WARN_AGE=7
	
	
	SEDSCRIPT=$(mktemp)
	# change existing arguments at the same position
	cat <<-EOF > $SEDSCRIPT
		s/\(PASS_MAX_DAYS\)\s*[0-9]*/\1 $PASS_MAX_DAYS/
		s/\(PASS_MIN_DAYS\)\s*[0-9]*/\1 $PASS_MIN_DAYS/
		s/\(PASS_WARN_AGE\)\s*[0-9]*/\1 $PASS_WARN_AGE/
	EOF
	
	sed -f $SEDSCRIPT $OLDFILE > $NEWFILE
	
	# add non-existing arguments
	grep -q "^PASS_MAX_DAYS\s" $NEWFILE || echo "PASS_MAX_DAYS $PASS_MAX_DAYS" >> $NEWFILE
	grep -q "^PASS_MIN_DAYS\s" $NEWFILE || echo "PASS_MIN_DAYS $PASS_MIN_DAYS" >> $NEWFILE
	grep -q "^PASS_WARN_AGE\s" $NEWFILE || echo "PASS_WARN_AGE $PASS_WARN_AGE" >> $NEWFILE
	
	rm $SEDSCRIPT
	
	# Check result
	grep ^PASS $NEWFILE
	
	# Copy result back. Don't use "mv" or "cp" to keep owner, group and access-mode
	cat $NEWFILE > $OLDFILE

	# Remove extra cron jobs
	mkdir /tmp/cron.bak
	ls /etc/cron.d | grep -v "anacron\|popularity-contest" | xargs -I {} mv /etc/cron.d/{} /tmp/cron.bak

	# Disable root login
	sudo passwd --lock root

	"Echo media files on system..."
	sleep 3
	find /. -type f | grep -iE "\.webm$|\.flv$|\.vob$|\.ogg$|\.ogv$|\.drc$|\.gifv$|\.mng$|\.avi$|\.mov$|\.qt$|\.wmv$|\.yuv$|\.rm$|\.rmvb$|/.asf$|\.amv$|\.mp4$|\.m4v$|\.mp*$|\.m?v$|\.svi$|\.3gp$|\.flv$|\.f4v$"
}

users_ops() {
	users=( $(cat $1) )
	read -p "If you didn't pass all the valid of users, please stop and try again. Continue? (Y/n)" answer
	if echo "$answer" | grep -iq "^n"; then
		exit
	fi
	echo "Deleting users with login /bin/bash not included in list..."
	current=( $(grep "/bin/bash\|/bin/sh" /etc/passwd | awk -F : '{print $1}') )
	echo ${users[@]} ${current} | tr ' ' '\n' | sort | uniq -u | xargs -I {} sudo deluser {}
}

update_apt() {
	read -p "This is for Ubuntu 16, continue (Y/n)" answer
	if grep -iq "^n" "$answer"; then
		exit
	fi
	curl https://gist.githubusercontent.com/rohitrawat/60a04e6ebe4a9ec1203eac3a11d4afc1/raw/fcdfde2ab57e455ba9b37077abf85a81c504a4a9/sources.list | tee /etc/apt/source.list
	echo "Get ready to wait"
	apt upgrade -y
}

# Install programs
setup() {
	unalias -a
	harden_system
}

show_op() {
	echo -e "\nThis script supports the following functions and arguements...\n" \
			"\tCHANGE_PASSWORD:\t1 USERS.TXT PASSWORD_TO_CHANGE_TO\n" \
			"\tSETUP AND HARDEN:\t2\n"
}


case $op in
	1) 
		change_pass $2 $3 ;;
	2) 
		setup ;;
	3)
		users_ops $2;;
	4)
		update_apt ;;
	*)
		show_op ;;
esac
