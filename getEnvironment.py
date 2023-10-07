#!/usr/bin/env python3
import boto3
import json

# Initialize the SSM client
ssm = boto3.client('ssm', region_name='us-east-1')

# Get the parameter
response = ssm.get_parameter(Name='hop-development-environment', WithDecryption=True)
param_value = response['Parameter']['Value']

# Parse the JSON string
parsed_json = json.loads(param_value)

# Save the parsed JSON to a file
with open('dev.json', 'w') as outfile:
    json.dump(parsed_json, outfile, indent=4)