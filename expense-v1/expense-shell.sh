#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
region="us-east-1"
hosted_zone_id="Z064550534ZXEXGIQB3I4"
domain_name="srikarlabs.space"


# user_id=$(id -u)

# if [ "$user_id" -ne 0 ]; then
#     echo "ERROR: please run with sudo access or root access"
#     exit 1
# fi

echo "started creating instance"

for instance in $@
do
echo "----------------------------------------"
echo "Launching instance: $instance"

instance_id=$(
  aws ec2 run-instances \
  --region "$region" \
  --image-id "$ami_id" \
  --instance-type "$instance_type" \
  --security-groups "$instance" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" \
  --query "Instances[].InstanceId" \
  --output text
)

echo "Launched Instance ID: ${instance_id}"       
#from the instance id we can get the ip address
## in the aws cli I was adding spaces so due to that i was faciing multiple issues and now i resolved tis
# how the query works, check the understanding and flow
# [ AWS launches server ] 
#        │
#        ▼ (Sends 50+ lines of JSON)
# [ --query "Instances[0].InstanceId" ] 
#        │
#        ▼ (Keeps only: "i-0abcd1234efgh5678")
# [ --output text ] 
#        │
#        ▼ (Removes quotes: i-0abcd1234efgh5678)
# [ instance_id=$( ... ) ] 
#        │
#        ▼ (Catches the text instead of printing it)
# Variable $instance_id now holds: i-0abcd1234efgh5678

echo "Waiting for $instance to enter running state..."
aws ec2 wait instance-running --region "$region" --instance-ids "$instance_id"
read -r private_ip public_ip <<< $(aws ec2 describe-instances \
  --region "$region" \
  --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].[PrivateIpAddress, PublicIpAddress]" \
  --output text
)

echo "Private IP: $private_ip"
echo "Public IP:  $public_ip"

 if [ "$instance" == "frontend" ]; then
    ip_to_use="$public_ip"
    record_name="${domain_name}" # Or use "${instance}.${domain_name}" if you prefer frontend.srikarlabs.space
  else
    ip_to_use="$private_ip"
    record_name="${instance}.${domain_name}"
  fi

echo "This is the record: ${record_name}"

  echo "Updating Route 53 record: $record_name -> $ip_to_use"

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$hosted_zone_id" \
    --change-batch '{
      "Comment": "Update DNS record for '"$instance"'",
      "Changes": [
        {
          "Action": "UPSERT",
          "ResourceRecordSet": {
            "Name": "'"$record_name"'",
            "Type": "A",
            "TTL": 1,
            "ResourceRecords": [
              {
                "Value": "'"$ip_to_use"'"
              }
            ]
          }
        }
      ]
    }' 

  echo "Successfully updated Route 53 for $record_name"
done
