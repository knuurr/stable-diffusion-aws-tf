terraform {
  required_version = ">= 1.7.2"
  required_providers {
    aws = ">= 5.35.0"
  }
}


provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}



resource "tls_private_key" "tls_key" {
  count     = var.use_ssh_key_from_file ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}


# Also creating SSH key from terraform
# https://stackoverflow.com/questions/49743220/how-to-create-an-ssh-key-in-terraform
resource "aws_key_pair" "ssh_key" {
  key_name   = var.ssh_key_tag_name
  public_key = var.use_ssh_key_from_file ? file(var.ssh_public_key_path) : tls_private_key.tls_key[0].public_key_openssh
  tags = {
    creator = var.ssh_key_tag_name
  }
}


# # Declare the AWS VPC resource
# resource "aws_vpc" "default" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_support = true
#   enable_dns_hostnames = true

#   tags = {
#     Name = "default-vpc"
#   }
# }


resource "aws_security_group" "ssh_only" {
  name        = "SSH-Only"
  description = "Allow SSH from anywhere"
  # vpc_id      = aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    creator = var.ssh_key_tag_name
  }
}

data "aws_ami" "latest_debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

resource "aws_instance" "aws_sd_ec2" {
  ami           = data.aws_ami.latest_debian.id
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.ssh_key.key_name
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#security_groups
  # https://stackoverflow.com/questions/67811623/putting-security-group-ids-of-a-vpc-in-a-list-using-terraform
  # subnet_id       = aws_subnet.selected_subnet.id
  # security_group   = [aws_security_group.ssh_only.name]
  vpc_security_group_ids = [aws_security_group.ssh_only.id]

  user_data = file(var.user_data_filename)
  tags = {
    INSTALL_AUTOMATIC1111 = var.install_automatic1111
    INSTALL_INVOKEAI      = var.install_invokeai
    GUI_TO_START          = var.gui_to_start
    creator               = var.ssh_key_tag_name
  }


  metadata_options {
    instance_metadata_tags = "enabled"
  }

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }


  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = var.spot_price
      spot_instance_type             = "persistent"
      instance_interruption_behavior = "stop"
    }
  }
}

# Provision with stopped state
# AWS does not currently have an EC2 API operation to determine an instance has finished processing user data. As a result, this resource can interfere with user data processing. For example, this resource may stop an instance while the user data script is in mid run.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_state
# resource "aws_ec2_instance_state" "test" {
#   instance_id = aws_instance.example.id
#   state       = "stopped"
# }

# Create an Alarm to stop the instance after 15 minutes of idling 
resource "aws_cloudwatch_metric_alarm" "instance_idle_alarm" {
  alarm_name          = "${var.ssh_key_tag_name}-stop-when-idle"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 5
  unit                = "Percent"

  dimensions = {
    InstanceId = aws_instance.aws_sd_ec2.id
  }

  alarm_actions = [
    "arn:aws:automate:${var.aws_region}:ec2:stop"
  ]
}
