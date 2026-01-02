#!/bin/bash
# Dynamic script that runs based on a tag called AutoStart
# to add more stages of starts/stops, implement a sleep after the if statement '$name == "first"'
# Author: StaticResponse


aws ec2 describe-instances > /opt/scripts/instancelist.json

wait

if [[ $1 == "on" ]]; then
  cat /dev/null > /opt/scripts/started.log
  for i in $instances; do
    name=$(jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$i\") | .Tags[] | select(.Key==\"AutoStart\").Value" /opt/scripts/instancelist.json)
    if [[ $name == "first" ]]; then
      aws ec2 start-instances --instance-ids $i
      echo $i >> /opt/scripts/started.log
    fi
  done
elif [[ $1 == "off" ]]; then
  cat /dev/null > /opt/scripts/stopped.log
  for i in $instances; do
    name=$(jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$i\") | .Tags[] | select(.Key==\"AutoStart\").Value" /opt/scripts/instancelist.json)
    if [[ $name == "first" ]]; then
      aws ec2 stop-instances --instance-ids $i
      echo $i >> /opt/scripts/stopped.log
    fi
  done
fi
