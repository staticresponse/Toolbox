import csv
import boto3
from concurrent.futures import ThreadPoolExecutor
import sys

class ASG:
    def __init__(self, asg_name, min_size, max_size, desired_capacity, instance_type, ami):
        self.asg_name = asg_name
        self.min_size = min_size
        self.max_size = max_size
        self.desired_capacity = desired_capacity
        self.instance_type = instance_type
        self.ami = ami

    def is_asg_config_same(self, asg_config):
        return (
            asg_config['MinSize'] == self.min_size and
            asg_config['MaxSize'] == self.max_size and
            asg_config['DesiredCapacity'] == self.desired_capacity and
            asg_config['LaunchTemplate']['LaunchTemplateData']['InstanceType'] == self.instance_type and
            asg_config['LaunchTemplate']['LaunchTemplateData']['ImageId'] == self.ami
        )

    def modify_asg(self):
        autoscaling_client = boto3.client('autoscaling')

        # Describe the Auto Scaling Group to get the current configuration
        response = autoscaling_client.describe_auto_scaling_groups(AutoScalingGroupNames=[self.asg_name])
        current_asg_config = response['AutoScalingGroups'][0]

        if not self.is_asg_config_same(current_asg_config):
            # Modify the Auto Scaling Group configuration
            autoscaling_client.update_auto_scaling_group(
                AutoScalingGroupName=self.asg_name,
                MinSize=self.min_size,
                MaxSize=self.max_size,
                DesiredCapacity=self.desired_capacity
            )

            # Get the launch template name from the Auto Scaling Group
            launch_template_name = current_asg_config['LaunchTemplate']['LaunchTemplateName']

            # Modify the launch template to update the instance type
            autoscaling_client.modify_launch_template(
                LaunchTemplateName=launch_template_name,
                Version='latest',  # Use the latest version of the launch template
                DefaultVersion=False,
                LaunchTemplateData={
                    'InstanceType': self.instance_type,
                    'ImageId': self.ami  # Add this line for AMI modification
                }
            )

            # Start an instance refresh
            response = autoscaling_client.start_instance_refresh(
                AutoScalingGroupName=self.asg_name,
                Strategy='Rolling'
            )

            # Print the instance refresh status
            print(f"Instance refresh started: {response['InstanceRefreshId']}")


def lambda_handler(event, context):
    file_path = event
    # Process the CSV file
    with open(file_path, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            new_asg = ASG(
                row['asg-name'],
                int(row['asg-min']),
                int(row['asg-max']),
                int(row['asg-des']),
                row['instance-type'],
                row['ami']
            )
            new_asg.modify_asg()

    return {'statusCode': 200, 'body': 'Lambda execution completed successfully.'}
