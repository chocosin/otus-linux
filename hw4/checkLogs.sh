#!/bin/bash

# lockfile
LOCK="$HOME/.loglock"
# protection against parallel start
if ( set -o noclobber; echo "$$" > $LOCK) 2> /dev/null
then
	trap 'echo trapped; rm -f '"$LOCK"'; exit $?' INT TERM EXIT
	echo "lock acquired"
else
	echo "Failed to acquire lockfile: $LOCK"
	echo "Held by $(cat $LOCK)"
	exit 1
fi

# config file with last read line
CONFIG="$HOME/.logwatcher"
# log file to analyze
LOG=access-4560-644067.log
# how many top ips to send in report
IPS_NUM=3
# how many top addresses to send in report
ADDR_NUM=6
# mail address to send report to
MAIL_ADDR=`whoami`

# command to send mail
sendMail="mail -s Logs $MAIL_ADDR"
# sendMail='cat'

if [[ -f "$CONFIG" ]]
then
	lastRead=$( cat ${CONFIG} )
else
	lastRead=1
fi

lastLine=`wc -l <${LOG} | sed -E 's/^[[:space:]]+//'`

if [[ ${lastRead} -ge ${lastLine} ]]
then
	echo "no new lines"
	exit 0
fi

# returns lines like "ip date method address code"
logs=$( sed -E -n '
	'$lastRead,$lastLine' {
		# change line to awkable line
		s/^([0-9\.]+) \- \- \[(.*)\] "([[:alnum:]]+) ([^[:space:]]+) HTTP\/1\.." ([[:digit:]]+).*/\1 \2 \3 \4 \5/p
	}' \
 $LOG )

# positions in line
ipN=1
date1N=2
date2N=3
methodN=4
addressN=5
codeN=6

# groups arguments at position $1
# returns top $2 most frequent arguments
groupLines()
{
	local key=$1
	local topLines=$(($2+1))
	awk -v key=$1 '
	{
		counts[$key]++;
	}
	END {
		for (i in counts) {
			print counts[i], i;
		}
	}
	' <<< "$logs" | sort -rn | sed "$topLines"',$ d'
}

# checks if status code is 5xx and
# returns formatted error
errorsList()
{
	awk -v code=$codeN \
	-v date1=$date1N -v date2=$date2N \
	-v methodN=$methodN \
	-v address=$addressN '
	{
		if ($code / 100 == 5) {
			printf("%s [%s %s] %s %s\n", $code, $date1, $date2, $methodN, $address)
		}
	}
	' <<< "$logs"
}

# takes dates from first and last lines
dateInterval()
{
	awk -v date1=$date1N -v date2=$date2N '
	BEGIN {line = 1}
	{
		if (line == 1) {
			startDate1 = $date1
			startDate2 = $date2
		}
		if (line == NR) {
			endDate1 = $date1
			endDate2 = $date2
		}
		line++
	}
	END {
		printf("Date interval between [%s %s] and [%s %s]\n", startDate1, startDate2, endDate1, endDate2)
	}
	' <<< "$logs"
}

$sendMail <<EOF
$(dateInterval)

top ips:
$(groupLines $ipN $IPS_NUM)

top addresses:
$(groupLines $addressN $ADDR_NUM)

status codes:
$(groupLines $codeN $lastLine)

all server errors:
$(errorsList)
EOF

echo ${lastLine} > ${CONFIG}
if [ -f $LOCK ]; then
	rm $LOCK
fi
