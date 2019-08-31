#!/bin/bash

jiff=`getconf CLK_TCK`

getStatN()
{
  awk '
    {print $'$1'}
  ' <<< "$2"
}

formatSeconds()
{
  seconds=$1
  mins=$(($1 / 60))
  secs=$(($1 % 60))
  printf '%d:%02d' "$mins" "$secs"
}

getStat()
{
  cat "/proc/$1/stat" 2>/dev/null
}
getStatus()
{
  cat "/proc/$1/status" 2>/dev/null
}
getCmdline()
{
  cat "/proc/$1/cmdline" 2>/dev/null
}
vmLock()
{
  local line=`grep "VmLck" <<< "$1"`
  local kbLocked=`sed -E 's/^VmLck:[[:space:]]+([[:digit:]]+).*/\1/' <<< $line`
  if [[ $kbLocked > 0 ]]; then echo -n L; fi
}
pstgid()
{
  local line=`grep "Tgid" <<< "$1"`
  local tgid=`sed -E 's/^Tgid:[[:space:]]+([[:digit:]]+).*/\1/' <<< $line`
  echo $tgid
}
stateIndex=1
pgroupIndex=3
sessionIndex=4
topPgroupIndex=6
utimeIndex=12
stimeIndex=13
niceIndex=17
nlwpIndex=18
pidLine()
{
  local pid=$1
  local stat=`getStat $pid`
  local status="`getStatus $pid`"
  if [ -z "$stat" -o -z "$status" ]; then exit; fi

  local statinfo=`sed -E 's/^[[:digit:]]+ \(.*\) (.*)/\1/' <<< "$stat"`
  local cmdName=`sed -E 's/^[[:digit:]]+ \((.*)\).*/\1/' <<< "$stat"`

  local state=`getStatN $stateIndex "$statinfo"`

  # is nice?
  local niceness=`getStatN $niceIndex "$statinfo"`
  if [[ $niceness -lt 0 ]]; then state="$state<"; fi
  if [[ $niceness -gt 0 ]]; then state="${state}N"; fi

  # has locked pages?
  local state="$state`vmLock "$status"`"

  # is session leader?
  local psSession=`getStatN $sessionIndex "$statinfo"`
  local tgid=`pstgid "$status"`
  if [[ $psSession == $tgid ]]; then state="${state}s"; fi

  # is multi threaded?
  local nlwp=`getStatN $nlwpIndex "$statinfo"`
  if [[ $nlwp -gt 1 ]]; then state="${state}l"; fi

  # is in the foreground?
  local pgroup=`getStatN $pgroupIndex "$statinfo"`
  local tpgroup=`getStatN $topPgroupIndex "$statinfo"`
  if [[ $pgroup == $tpgroup ]]; then state="${state}+"; fi

  # utime + stime
  local utime=`getStatN $utimeIndex "$statinfo"`
  local stime=`getStatN $stimeIndex "$statinfo"`
  local timeSeconds=$(( ($utime + $stime) / $jiff))
  local time=`formatSeconds $timeSeconds`

  cmdline=`getCmdline $pid | tr '\000' ' '`
  if [ -z "$cmdline" ]; then
    cmdline="[$cmdName]"
  fi

  printf '%5d %-8s %-6s %6s %s\n' "$pid" '?' "$state" "$time" "$cmdline"
}
printf '%5s %-8s %-6s %6s %s\n' "PID" 'TTY' "STAT" "TIME" "COMMAND"
pids=(`ls -1 /proc/ | grep -E '^[[:digit:]]+$' | sort -n`)
for pid in "${pids[@]}"; do
  pidLine $pid
done
