!#/bin/bash

#parameters for the snapshot manager - instance id, volume id's, instance name
iid=$(ec2-metadata -i | awk -F ' ' '{print $2}')
vols=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$iid --query "Volumes[*].VolumeId" --output text)
iname=$(aws ec2 describe-instances --instance-ids $iid --query "Reservations[*].Instances[*].Tags[?Key=='Name'].Value" --output text)


### Create the snapshots of the volumes attached to current instance
for i in $vols; do
        aws ec2 create-snapshot --volume-id $i --description "Created by Snapshot Manager - $iname $iid"
done

# sleep is required because it can take some time for aws to initialize the snapshot
sleep 5m

# Tag the new snapshot with a name and purpose (needed for retention policy)
t=$(date +%Y-%m-%d)
for i in $vols; do
        snap=$(aws ec2 describe-snapshots --filters Name=volume-id,Values=$i --query "Snapshots[?StartTime >= \`$t\`].{ID:SnapshotId}" --output text)
        dow=$(date +%u)
        if [ $dow -eq 1  ]
        then
                tagname="${iname}_${iid}_${t}_Weekly"
                aws ec2 create-tags --resources $snap --tags Key=Purpose,Value=Weekly
                aws ec2 create-tags --resources $snap --tags Key=Name,Value=$tagname
        else
                tagname="${iname}_${iid}_${t}"
                aws ec2 create-tags --resources $snap --tags Key=Purpose,Value=Daily
                aws ec2 create-tags --resources $snap --tags Key=Name,Value=$tagname
        fi
done



# Remove old daily snapshots after 7 days.
old=$(date  -d "now -6 days" +%Y-%m-%d)
for i in $vols; do
        snap=$(aws ec2 describe-snapshots --filters Name=tag:Purpose,Values=Daily Name=volume-id,Values=$i --query "Snapshots[?StartTime <= \`$old\`].{ID:SnapshotId}" --output text)
        aws ec2 delete-snapshot --snapshot-id $snap
done
