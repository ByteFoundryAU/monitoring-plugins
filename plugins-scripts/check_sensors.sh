#!/bin/sh

PATH="@TRUSTED_PATH@"
export PATH
PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="@NP_VERSION@"

. $PROGPATH/utils.sh

print_usage() {
	echo "Usage: $PROGNAME" [--ignore-fault]
}

print_help() {
	print_revision $PROGNAME $REVISION
	echo ""
	print_usage
	echo ""
	echo "This plugin checks hardware status using the lm_sensors package."
	echo ""
	support
	exit $STATE_OK
}

linux_sensors() {
	sensordata=`sensors 2>&1`
	status=$?
	if test ${status} -eq 127; then
		text="SENSORS UNKNOWN - command not found (did you install lmsensors?)"
		exit=$STATE_UNKNOWN
	elif test ${status} -ne 0; then
		text="WARNING - sensors returned state $status"
		exit=$STATE_WARNING
	elif echo ${sensordata} | egrep ALARM > /dev/null; then
		text="SENSOR CRITICAL - Sensor alarm detected!"
		exit=$STATE_CRITICAL
	elif echo ${sensordata} | egrep FAULT > /dev/null \
	    && test "$1" != "-i" -a "$1" != "--ignore-fault"; then
		text="SENSOR UNKNOWN - Sensor reported fault"
		exit=$STATE_UNKNOWN
	else
		text="SENSORS OK"
		exit=$STATE_OK
	fi

	echo "$text"
	if test "$1" = "-v" -o "$1" = "--verbose"; then
		echo ${sensordata}
	fi
	exit $exit
}


freebsd_temperatures() {
	sensordata=`sysctl -a hw.acpi.thermal.tz0.temperature hw.acpi.thermal.tz0._CRT 2>&1`
	status=$?

	if test ${status} -eq 127; then
		text="SYSCTL UNKNOWN - command not found (how is sysctl missing?)"
		exit=$STATE_UNKNOWN
	elif test ${status} -ne 0; then
		text="WARNING - sysctl returned state $status"
		exit=$STATE_WARNING
	fi

	if test -n "${sensordata}"; then
		# hw.acpi.thermal.tz0.temperature: XX.XC
		temp=`echo $sensordata | awk '{ print $2 }' | sed 's/\.[0-9][CF]$//'`
		# hw.acpi.thermal.tz0._CRT: XX.XC
		max=`echo $sensordata | awk '{ print $4 }' | sed 's/\.[0-9][CF]$//'`
		warn="$(( ($max * 8)/10 ))"

		if test $temp -ge $max; then
			text="CRITICAL - tz0 exceeding max temp"
			exit=$STATE_CRITICAL
		elif test $temp -ge $warn; then
			text="WARNING- tz0 exceeding 80% max temp"
			exit=$STATE_WARNING
		else
			text="TEMPERATURES OK"
			exit=$STATE_OK
		fi

		echo "$text"
		exit $exit
	fi


}

case "$1" in
	--help)
		print_help
		exit $STATE_OK
		;;
	-h)
		print_help
		exit $STATE_OK
		;;
	--version)
		print_revision $PROGNAME $REVISION
		exit $STATE_OK
		;;
	-V)
		print_revision $PROGNAME $REVISION
		exit $STATE_OK
		;;
	*)
		os=`uname -o`
		if echo ${os} | grep Linux > /dev/null; then
			linux_sensors
		fi
		if echo ${os} | grep FreeBSD > /dev/null; then
			freebsd_temperatures
		fi
		echo "Unsupported OS $os"
		exit $STATE_UNKNOWN
		;;
esac
