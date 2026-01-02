#!/bin/bash
cat /dev/null > /var/log/mem.log
memfree=`cat /proc/meminfo | grep MemFree | awk '{print $2}'`
memtotal=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
pfree=`bc -l <<< "$memfree * 100 / $memtotal"`
printf "%.3f\n" $pfree >> /var/log/mem.log
