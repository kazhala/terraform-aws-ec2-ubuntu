import os

import boto3

client = boto3.client("ec2")


def lambda_handler(event, context):
    instance_id = os.getenv("INSTANCE")
    if not instance_id:
        return

    client.stop_instances(InstanceIds=[instance_id])
