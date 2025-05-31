# Environment Configuration for Dev
region      = "eu-north-1"
environment = "dev"

# Project Settings
project_name = "gitops-demo"
bucket_name  = "subinclabs-demo"

# Lambda Configuration
lambda_handler = "bootstrap"

# EC2 Configuration
# Set this to your actual key pair name if you have one
key_name      = "gitops-demo-key"
instance_type = "t3.micro"

# VPC Configuration
# vpc_id = "vpc-xxxxxxxxx"  # Replace with actual VPC ID if not using default 
