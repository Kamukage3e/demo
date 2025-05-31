data "aws_vpc" "default" {
  count   = var.vpc_id == "demo-vpc" ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  count = var.vpc_id != "demo-vpc" ? 1 : 0
  id    = var.vpc_id
}

locals {
  vpc_id = var.vpc_id == "demo-vpc" ? data.aws_vpc.default[0].id : data.aws_vpc.selected[0].id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.ec2_name}_sg"
  description = "Security group for ${var.ec2_name}"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ec2_name}_sg"
  }
}

resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = var.key_name != "gitops-demo-key" ? var.key_name : null
  user_data                   = var.user_data
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnets.default.ids[0]

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = {
    Name        = var.ec2_name
    Environment = "dev"
    Service     = "worker"
  }
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ec2.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ec2.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}

variable "ec2_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "gitops-demo-key"
}

variable "user_data" {
  description = "User data script to run on instance startup"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to launch the instance in"
  type        = string
  default     = "demo-vpc"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
