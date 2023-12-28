
# hop-ec2

## Introduction

Welcome to `hop-ec2`, a project designed to automate the deployment and configuration of Apache Hop on an AWS EC2 instance using Terraform and Ansible. This project sets up an EC2 instance, installs necessary software, and configures environmental variables and scripts for Apache Hop.

## Prerequisites

Before you begin, ensure you have the following installed on your machine:

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) - For configuring the EC2 instance.
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) - For provisioning AWS resources.

## AWS Credentials Setup

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/usbrandon/hop-ec2.git
   cd hop-ec2
   ```

2. Run the `update_aws_profile.sh` script to configure your AWS profile for Terraform:
   ```bash
   ./update_aws_profile.sh
   ```
   Follow the prompts to input your AWS credentials.

## Deploying with Terraform

1. **Initialize Terraform**: Set up Terraform to manage the infrastructure:
   ```bash
   terraform init
   ```

2. **Plan Deployment**: Review the changes Terraform will make to your AWS environment:
   ```bash
   terraform plan
   ```

3. **Apply Configuration**: Create the resources in AWS:
   ```bash
   terraform apply
   ```
   Confirm the action when prompted.

## Accessing Your EC2 Instance

- After the successful deployment, Terraform will output the public IP of the EC2 instance.
- Use SSH to connect to the instance:
  ```bash
  ssh -i /path/to/your/key.pem ubuntu@<EC2-Public-IP>
  ```
  Terraform will detect if you are on Linux or Windows and create a connection script for you.
  ```
   ./connect_to_ec2.sh
  ```

## Post-Deployment Configuration

After deploying the EC2 instance, Ansible will automatically configure the environment for Apache Hop. However, you should verify that everything is set up as expected:

1. Check if Apache Hop is correctly installed and configured.
   Hop ends up in the /opt/hop folder.
2. Verify environmental variables and script aliases.
   ```env```

## Troubleshooting

- If you encounter any issues with the deployment, check the Terraform and Ansible logs for detailed error messages.
- Ensure your AWS account has the necessary permissions and quotas to create the resources.

## Contributing

Contributions to `hop-ec2` are welcome. Please read the contributing guidelines before submitting pull requests.
