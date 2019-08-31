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
