#!/bin/bash

# put your sns topic arn and region here to use aws sns to send a weekly email
snsTopic=""
snsRegion=""
cat /dev/null > /data/admin/diskFull.txt

df -H | grep -vE '^Filesystem|tmpfs' | awk '{ print $5 " " $1}' | while read output;

do
  echo $output
  usep=$(echo $output | awk '{print $1}' | cut -f '%' -f1)
  partition=$(echo $output | awk '{ print $2}')
  echo "$partition - ($usep%)" >> /data/admin/diskFull.txt
done


# send the sns message
aws sns publish --region $snsRegion --topic-arn $snsTopic --message file:////data/admin/diskFull.txt --suject "Disk Space Notification"
 
