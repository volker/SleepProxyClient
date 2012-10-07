#!/usr/bin/env bash

export PATH=/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=en_US.utf8

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# checkSleep
#
# execute SleepProxyClient and pm-suspend if two runs after each other are positive
#
#	Creteria:
#		- no user logged in (remote + local) 
#		- no non-local active tcp connections
#
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#used to check for a previous successfull run
TMPFILE="/tmp/checkSleep"

#value will be returned. 0 if the creteria was fullfilled
RET=0

# network interface to use
IFACE="eth0"

SCRIPT_DIR=$(dirname $0)

# run SleepProxyClient
function doSleep {
	logger "checkSleep: initiating sleep"
#	pm-suspend
	acpiconf -s 3
	logger "checkSleep: awake!"
}

# check the creteria
function doCheck {

	RESULT=0

	# check for logged in user
	USERS=`who | wc -l`
	if [ $USERS -gt 0 ]
	then
		echo "Active users: $USERS" >> /home/volker/checksleep_debug.txt
		RESULT=1
	fi


	# check if no non-local connection is active
	CONNS=`netstat -p tcp -n | grep -v "127.0.0.1" | grep "ESTABLISHED" | wc -l`
	if [ $CONNS -gt 0 ]
	then
		echo "Active connections: $CONNS" >> /home/volker/checksleep_debug.txt
		RESULT=1
	fi

	#check for heavy processing/cpu load,
	if test -f /proc/loadavg
	then
		LOAD5MINAVG=`cat /proc/loadavg  | cut -d " " -f 2`
	elif test -f /sbin/sysctl
	then
		LOAD5MINAVG=`sysctl vm.loadavg | cut -d " " -f 5`
	fi

	if [ `echo "$LOAD5MINAVG > 1" | bc` -gt 0 ]
	then
		echo "5 min avg load > 1" >> /home/volker/checksleep_debug.txt
		RESULT=1
	fi
	return $RESULT
}

doCheck
if [ $? -eq 0 ]
then
	# we only want to go to sleep if two successive doCheck runs were successfull 
	# check whether the previous run created the file to signal success 
	if [ -e "$TMPFILE" ]
	then
		# cleanup
		rm -f "$TMPFILE"
		
		# initiate sleep
		echo "Initiate sleep" >> /home/volker/checksleep_debug.txt
		doSleep
	else
		# mark run as positive
		echo "Positive run" >> /home/volker/checksleep_debug.txt
		touch "$TMPFILE"
	fi
else
	rm -f "$TMPFILE"
	echo "Negative run" >> /home/volker/checksleep_debug.txt
	RET=1
fi

exit $RET
