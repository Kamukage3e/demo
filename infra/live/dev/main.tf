terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.9.0"

  backend "s3" {
    # Modern S3-only backend with native locking (no DynamoDB needed)
    # Uncomment and configure these after creating the S3 bucket:
    bucket       = "subinclabs-demo"
    key          = "dev/terraform.tfstate"
    region       = "eu-north-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "EC2 keypair name"
  type        = string
  default     = "gitops-demo-key"
}

variable "vpc_id" {
  description = "VPC id to launch EC2"
  type        = string
  default     = "demo-vpc"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "gitops-demo"
}

variable "bucket_name" {
  description = "Base name for the S3 bucket"
  type        = string
  default     = "gitops-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "bootstrap"
}

# Generate unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "s3_static_site" {
  source          = "../../modules/s3-static-site"
  bucket_name     = "${var.bucket_name}-static-site-${random_id.bucket_suffix.hex}"
  index_html_path = "../../../app/frontend/index.html"
}

module "lambda_api" {
  source          = "../../modules/lambda-api"
  lambda_name     = "${var.project_name}-lambda"
  lambda_zip_path = "../../../app/lambda-jobs-api/lambda.zip"
  lambda_handler  = var.lambda_handler
  stage           = var.environment
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2_go_service" {
  source        = "../../modules/ec2-go-service"
  ec2_name      = "${var.project_name}-go-ec2"
  ami_id        = data.aws_ami.ubuntu.id
  key_name      = var.key_name
  vpc_id        = var.vpc_id
  instance_type = var.instance_type
  user_data     = file("../../../app/ec2-worker-service/user-data.sh")
}

# Outputs
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2_go_service.public_ip
}

output "lambda_api_url" {
  description = "URL of the Lambda API"
  value       = module.lambda_api.api_url
}

output "static_site_url" {
  description = "URL of the static site"
  value       = "http://${module.s3_static_site.website_endpoint}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the static site"
  value       = module.s3_static_site.bucket_name
}

# Summary output for easy access
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    static_site_url = "http://${module.s3_static_site.website_endpoint}"
    api_url         = module.lambda_api.api_url
    ec2_public_ip   = module.ec2_go_service.public_ip
    ec2_ssh_command = var.key_name != "gitops-demo-key" ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2_go_service.public_ip}" : "Key pair not configured"
  }
}
