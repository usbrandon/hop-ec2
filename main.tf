# Local variable to determine if Terraform is being executed on a Windows environment.
locals {
  is_windows = terraform.workspace == "windows"
  dev_json_content = file("${path.module}/hop-environment/dev.json") # Read the contents of dev.json
}

# AWS Provider configuration specifying the region and profile.
provider "aws" {
  region  = "us-east-1"
  profile = "hop"
}

variable "region" {
  description = "The AWS region to deploy into"
  default     = "us-east-1"
}

# Security Group allowing SSH traffic.
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  # Inbound rule allowing SSH.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule allowing all traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
    Name         = "allow_ssh"
    PROJECT_NAME = "apache_hop"
  }
}

# IAM role to be assumed by EC2 to access SSM parameter.
resource "aws_iam_role" "ssm_role" {
  name = "SSMParameterRoleForEC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

    tags = {
    Name         = "allow_ssh"
    PROJECT_NAME = "apache_hop"
  }
}

# IAM policy to allow EC2 to read the specific SSM parameter.
resource "aws_iam_role_policy" "ssm_policy" {
  name = "SSMReadPolicy"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ssm:GetParameter"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/hop-development-environment"
    }]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name   = "SSMReadPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ssm:GetParameter"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/hop-development-environment"
    }]
  })
}

resource "aws_iam_policy_attachment" "ssm_policy_attachment" {
  name       = "SSMPolicyAttachment"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_policy" "s3_access_policy" {
  name   = "S3ReadWriteListPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::hop-audit-logs-2023-12-28",
          "arn:aws:s3:::hop-audit-logs-2023-12-28/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "s3:ListAllMyBuckets",
        Resource = "*"
      }
    ]
  })
}



resource "aws_iam_policy_attachment" "s3_policy_attachment" {
  name       = "S3PolicyAttachment"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = aws_iam_policy.s3_access_policy.arn
}



# IAM instance profile to be associated with EC2.
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

# Data source to get the current AWS account ID.
data "aws_caller_identity" "current" {}

# Create the SSM parameter using the content of dev.json.
resource "aws_ssm_parameter" "hop_dev_env" {
  name  = "hop-development-environment"
  type  = "String"
  value = local.dev_json_content

  tags = {
    Name         = "hop-development-environment"
    PROJECT_NAME = "apache_hop"
  }
}

# Uploads the local public key to AWS, making it usable for EC2 instances.
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("id_ed25519.pub")

  tags = {
    Name = "deployer-key"
    PROJECT_NAME = "apache_hop"
  }
}

# EC2 instance creation.
resource "aws_instance" "hop" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "hop-ec2"
    PROJECT_NAME = "apache_hop"
  }
}

# Outputs the public IP of the EC2 instance for external reference.
output "instance_public_ip" {
  value = aws_instance.hop.public_ip
}

# Generates an Ansible inventory file with the EC2 instance's IP.
resource "local_file" "ansible_inventory" {
  content  = "[ec2]\n${aws_instance.hop.public_ip}"
  filename = "${path.module}/inventory.ini"
}

# After the EC2 instance is up and the inventory file is created, run the Ansible playbook.
resource "null_resource" "run_ansible" {
  # Uses the EC2 instance and inventory file as triggers to ensure Ansible runs post-creation.
  triggers = {
    instance_id = aws_instance.hop.id
    inventory   = local_file.ansible_inventory.id
  }

  # Introduce a delay
  provisioner "local-exec" {
    command = "sleep 60"  # Delay for 60 seconds
  }

  # Executes the Ansible playbook against the new EC2 instance.
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local_file.ansible_inventory.filename} -u ubuntu configure_ec2.yml"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}

# On Windows environments, generate a .bat script to SSH into the EC2 instance.
resource "local_file" "ssh_script_windows" {
  count    = local.is_windows ? 1 : 0
  content  = "@echo off\nssh -i ~\\.ssh\\id_ed25519 ubuntu@${aws_instance.hop.public_ip}"
  filename = "${path.module}/connect_to_ec2.bat"
}

# On non-Windows (e.g., Linux) environments, generate a .sh script to SSH into the EC2 instance.
resource "local_file" "ssh_script_linux" {
  count    = local.is_windows ? 0 : 1
  content  = "#!/bin/bash\nssh -i ~/.ssh/id_ed25519 ubuntu@${aws_instance.hop.public_ip}"
  filename = "${path.module}/connect_to_ec2.sh"
  
  # Makes the .sh script executable.
  provisioner "local-exec" {
    command = "chmod 0755 ${self.filename}"
  }
}

# S3 Bucket for Audit Logs
resource "aws_s3_bucket" "hop_audit_logs" {
  bucket = "hop-audit-logs-2023-12-28"

  tags = {
    Name         = "hop_audit_logs"
    PROJECT_NAME = "apache_hop"
  }
}