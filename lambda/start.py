import os

import boto3

client = boto3.client("ec2")
waiter = client.get_waiter("instance_running")
sns = boto3.client("sns")


def lambda_handler(event, context):
    instance_id = os.getenv("INSTANCE")
    if not instance_id:
        return

    client.start_instances(InstanceIds=[instance_id])

    if os.getenv("TOPIC_ARN"):
        waiter.wait(InstanceIds=[instance_id])
        instance_details = client.describe_instances(InstanceIds=[instance_id])
        message = instance_details["Reservations"][0]["Instances"][0]["PublicDnsName"]
        sns.publish(TopicArn=os.getenv("TOPIC_ARN"), Message=message, Subject="EC2 DNS")
