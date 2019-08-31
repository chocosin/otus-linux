#### ps script
Состояние взял из функции ps:
```
// This state display is Unix98 compliant and has lots of info like BSD.
static int pr_stat(char *restrict const outbuf, const proc_t *restrict const pp){
    int end = 0;
    outbuf[end++] = pp->state;
//  if(pp->rss==0 && pp->state!='Z')  outbuf[end++] = 'W'; // useless "swapped out"
    if(pp->nice < 0)                  outbuf[end++] = '<';
    if(pp->nice > 0)                  outbuf[end++] = 'N';
// In this order, NetBSD would add:
//     traced   'X'
//     systrace 'x'
//     exiting  'E' (not printed for zombies)
//     vforked  'V'
//     system   'K' (and do not print 'L' too)
    if(pp->vm_lock)                   outbuf[end++] = 'L';
    if(pp->session == pp->tgid)       outbuf[end++] = 's'; // session leader
    if(pp->nlwp > 1)                  outbuf[end++] = 'l'; // multi-threaded
    if(pp->pgrp == pp->tpgid)         outbuf[end++] = '+'; // in foreground process group
    outbuf[end] = '\0';
    return end;
}
```
Параметры брал из `/proc/pid/stat` и `/proc/pid/status`.

TTY пока всегда `?`.

Для времени форматирование сделал по функции ps:
```
static int pr_bsdtime(char *restrict const outbuf, const proc_t *restrict const pp){
    unsigned long long t;
    unsigned u;
    t = pp->utime + pp->stime;
    if(include_dead_children) t += (pp->cutime + pp->cstime);
    u = t / Hertz;
    return snprintf(outbuf, COLWID, "%3u:%02u", u/60U, u%60U);
}
```
То есть тут будут просто минуты и секунды без часов и дней.

Herts взял из `getconf CLK_TCK`.

utime, stime взял из `/proc/pid/stat`.

В форматировании просто оставил 6 символов для времени.

Команду брал из `/proc/pid/cmdline` заменяя `\0` на пробелы. В случае пустой строки брал название команды из `/proc/pid/stat` в квадратных скобках.

Результат запуска:
```
  PID TTY      STAT     TIME COMMAND
    1 ?        Ss       0:02 /usr/lib/systemd/systemd --switched-root --system --deserialize 21
    2 ?        S        0:00 [kthreadd]
    3 ?        S        0:00 [ksoftirqd/0]
    5 ?        S<       0:00 [kworker/0:0H]
    7 ?        S        0:00 [migration/0]
    8 ?        S        0:00 [rcu_bh]
    9 ?        R        0:01 [rcu_sched]
   10 ?        S<       0:00 [lru-add-drain]
   11 ?        S        0:00 [watchdog/0]
   13 ?        S        0:00 [kdevtmpfs]
   14 ?        S<       0:00 [netns]
   15 ?        S        0:00 [khungtaskd]
   16 ?        S<       0:00 [writeback]
   17 ?        S<       0:00 [kintegrityd]
   18 ?        S<       0:00 [bioset]
   19 ?        S<       0:00 [bioset]
   20 ?        S<       0:00 [bioset]
   21 ?        S<       0:00 [kblockd]
   22 ?        S<       0:00 [md]
   23 ?        S<       0:00 [edac-poller]
   24 ?        S<       0:00 [watchdogd]
   26 ?        S        0:00 [kworker/u2:1]
   33 ?        S        0:00 [kswapd0]
   34 ?        SN       0:00 [ksmd]
   35 ?        SN       0:00 [khugepaged]
   36 ?        S<       0:00 [crypto]
   44 ?        S<       0:00 [kthrotld]
   45 ?        S<       0:00 [kmpath_rdacd]
   46 ?        S<       0:00 [kaluad]
   47 ?        S<       0:00 [kpsmoused]
   48 ?        S<       0:00 [ipv6_addrconf]
   62 ?        S<       0:00 [deferwq]
   93 ?        S        0:00 [kauditd]
  583 ?        S<       0:00 [ata_sff]
  615 ?        S        0:00 [scsi_eh_0]
  624 ?        S<       0:00 [scsi_tmf_0]
  634 ?        S        0:00 [scsi_eh_1]
  644 ?        S<       0:00 [scsi_tmf_1]
  664 ?        S        0:00 [kworker/u2:3]
  974 ?        S<       0:00 [bioset]
  979 ?        S<       0:00 [xfsalloc]
  984 ?        S<       0:00 [xfs_mru_cache]
  989 ?        S<       0:00 [xfs-buf/sda1]
  990 ?        S<       0:00 [xfs-data/sda1]
  993 ?        S<       0:00 [xfs-conv/sda1]
  994 ?        S<       0:00 [xfs-cil/sda1]
  995 ?        S<       0:00 [xfs-reclaim/sda]
  996 ?        S<       0:00 [xfs-log/sda1]
  997 ?        S<       0:00 [xfs-eofblocks/s]
  998 ?        S        0:00 [xfsaild/sda1]
  999 ?        S<       0:00 [kworker/0:1H]
 1050 ?        Ss       0:00 /usr/lib/systemd/systemd-journald
 1086 ?        Ss       0:00 /usr/lib/systemd/systemd-udevd
 1191 ?        S<sl     0:00 /sbin/auditd
 1288 ?        S<       0:00 [rpciod]
 1289 ?        S<       0:00 [xprtiod]
 1505 ?        Ssl      0:00 /usr/lib/polkit-1/polkitd --no-debug
 1521 ?        Ssl      0:00 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
 1566 ?        Ss       0:00 /sbin/rpcbind -w
 1670 ?        Ssl      0:00 /usr/sbin/NetworkManager --no-daemon
 1698 ?        Ss       0:00 /usr/lib/systemd/systemd-logind
 1749 ?        Ssl      0:00 /usr/sbin/gssproxy -D
 1755 ?        S        0:01 /usr/sbin/chronyd
 1850 ?        Ss+      0:00 /sbin/agetty --noclear tty1 linux
 1859 ?        Ss       0:00 /usr/sbin/crond -n
 2069 ?        S        0:00 [kworker/0:0]
 2370 ?        S        0:00 /sbin/dhclient -d -q -sf /usr/libexec/nm-dhcp-helper -pf /var/run/dhclient-eth0.pid -lf /var/lib/NetworkManager/dhclient-5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03-eth0.lease -cf /var/lib/NetworkManager/dhclient-eth0.conf eth0
 2421 ?        Ssl      0:01 /usr/sbin/rsyslogd -n
 2422 ?        Ss       0:00 /usr/sbin/sshd -D -u0
 2425 ?        Ssl      0:02 /usr/bin/python2 -Es /usr/sbin/tuned -l -P
 2548 ?        S        0:00 [kworker/0:2]
 2608 ?        Ss       0:00 /usr/libexec/postfix/master -w
 2621 ?        S        0:00 qmgr -l -t unix -u
 2708 ?        S+       0:00 /bin/bash /vagrant/ps.sh
```
