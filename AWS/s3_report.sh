#!/bin/bash

# this script is used for looking up items in s3 that follow this file structure
# s3://<data-bucket-name>/date/

#list variable holds the data bucket names to check
list=`cat configlist.txt`
DAYS=$1
echo "Report of contents" > report.txt

#loop through each bucket in configlist.txt
for i in $list
do
  #loop through the number of days in the month.
  for j in {1..$DAYS}
  do
    DIR="${i}/${j}/"    
    # comment out aws line and uncomment echo line to verify proper bucket structure
    # echo $DIR
    aws s3 ls s3://$DIR >> report.txt
  done
done
 
