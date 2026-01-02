#!/bin/bash
# place into cron to run automatically
# dependent on the bc package for doing math
# can monitor the log with monitoring software and create automated actions

cat /dev/null > /var/log/piTemp.log
temp=`cat /sys/class/thermal/thermal_zone0/temp`
degrees=`/opt/scripts/bc-1.07/bc/bc -l <<< "($temp / 1000) * 9 /5"`
printf "%.3f\n" $degrees >> /var/log/piTemp.log
