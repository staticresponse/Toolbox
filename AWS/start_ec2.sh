#!/bin/bash

# author: Mike Lewis
# Creation date: 05/18/2020
# script to start instances that are not in a running state

aws ec2 describe-instances > /opt/scripts/instancelist.json

wait

instances=$(jq -r '.Reservations[].Instances[].InstanceId' /opt/scripts/instancelist.json)

for i in $instances; do
  states=$(jq -r ".Reservatons[].Instances[] | select(.InstanceId==\"$i\") | .State.Code /opt/scripts/instancelist.json)
  for s in $states; do
    if [[ $s != 16 ]]; then
      aws ec2 start-instances --instance-ids $1
    fi
  done
done
