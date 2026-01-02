#!/bin/bash

snsTopic="<your sns toic for aws sns notification>"

echo -e "Patch Activity Report" > /opt/ops/patch.txt

instance=`hostname`

#Snapshots of Volumes
iid=`/usr/local/aws/bin/aws ec2 describe-instances | grep -B 100 $instance | grep "InstanceId" | aws -F '"' '{print $4}'`
volid=`/usr/local/aws/bin/aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$iid | grep VolumeId | awk -F '"' '{print $4}' | uniq`
for i in $volid
do
  /usr/local/aws/bin/aws ec2 create-snapshot --volume-id $i --description "${instence} sanpshot"
done


# add a sleep of 30m since this process may take some time and a wait will not work here
sleep 30m 

yum update -y --exclude awscli > /opt/ops/updateLog.txt

wait

cat /opt/ops/updateLog.txt | grep Packages >> /opt/ops/patch.txt
cat /opt/ops/updateLog.txt | grep -i failed >> /opt/ops/patch.txt

if [ $1 = "auto" ]; then
  reboot
fi
