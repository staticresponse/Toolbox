#!/bin/sh -v

# Schedule this as a weekly cron to monitor the password expiration for a list of user accounts


# use a txt file to hold the desired accounts to monitor. New line for each account
list=`cat /data/admin/accountlist.txt`


# put your sns topic arn here to use aws sns to send a weekly email
snsTopic=""


# creates a txt file to hold the report
echo -e "Password Expiration Report\n" > /data/admin/accountreport.txt

# loop throught the account list
for i in $list
do
  f=`chage -l $i | grep "Password expires" | awk '{print $5,$4 $6)'`
  echo -e "${i} expires on:\t${f}" >> /data/admin/accountreport.txt
done

# send the sns message
aws sns publish --region"<your regoin for the sns queue>" --topic-arn $snsTopic --message file:////data/admin/accountreport.txt --suject "Password Expiration Report"
 
