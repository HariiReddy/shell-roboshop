#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-06ee180b7b4d74ff0"
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z074616934BLNLK5UXH91"
DOMAIN_NAME="harireddy.fun"

for instance in ${INSTANCES[@]}
do
    Instance_ID=$(aws ec2 run-instances \
    --image-id ami-09c813fb71547fc4f \
    --instance-type t2.micro \
    --security-group-ids sg-06ee180b7b4d74ff0 \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query "Instances[0].InstanceId" \
    --output text)

    # Check if instance was actually created
    if [ -z "$Instance_ID" ]; then
       echo "Failed to create instance for $instance"
       continue
    fi

    # Wait for instance to be ready
    aws ec2 wait instance-running --instance-ids "$Instance_ID"

    # Get IP based on instance type
    if [ "$instance" != "frontend" ]; then
       IP=$(aws ec2 describe-instances \
           --instance-ids "$Instance_ID" \
           --query "Reservations[0].Instances[0].PrivateIpAddress" \
           --output text)
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids "$Instance_ID" \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)
    fi
    echo "$instance IP address: $IP"

     aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch file://<(cat <<EOF
{
  "Comment": "Creating or updating a record set for $instance",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$instance.$DOMAIN_NAME",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$IP"
          }
        ]
      }
    }
  ]
}
EOF
)        
done