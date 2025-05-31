# GitOps Demo: Internal Developer Portal

A complete GitOps demonstration showcasing an internal developer portal built with modern cloud-native technologies.

## 🏗️ Architecture

This demo implements a three-tier architecture:

- **Frontend**: Static HTML/JS dashboard hosted on S3
- **API Backend**: Go Lambda function with API Gateway for job management
- **Worker Service**: Go application on EC2 for long-running processes
- **Infrastructure**: Terraform modules with GitHub Actions CI/CD

## 🚀 Features

- **Job Management**: Trigger and monitor background jobs (CI, backups, deployments)
- **Real-time Status**: Health monitoring and job history
- **Modern UI**: Responsive design with Tailwind CSS and Alpine.js
- **GitOps Workflow**: Infrastructure as Code with automated deployments
- **Security**: Proper IAM roles, VPC configuration, and encrypted storage

## 📋 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.3.0
- GitHub repository with Actions enabled
- (Optional) EC2 Key Pair for SSH access

## 🔧 Setup Instructions

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd demo
```

### 2. Configure AWS Credentials

Set up GitHub Secrets for AWS access:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 3. (Optional) Set up Remote State Backend

For production use, configure remote state with the modern S3-only approach:

```bash
# Create S3 bucket for state
aws s3 mb s3://gitops-demo-terraform-state-$(date +%s)

# Enable versioning (highly recommended)
aws s3api put-bucket-versioning \
    --bucket gitops-demo-terraform-state-$(date +%s) \
    --versioning-configuration Status=Enabled
```

Then uncomment and configure the backend in `infra/live/dev/main.tf`:

```hcl
backend "s3" {
  bucket       = "your-unique-bucket-name"
  key          = "dev/terraform.tfstate"
  region       = "eu-north-1"
  encrypt      = true
  use_lockfile = true  # S3 native locking (no DynamoDB needed!)
}
```

**Note**: This uses Terraform's new S3 native locking feature (Terraform 1.9.0+) which eliminates the need for DynamoDB tables, simplifying your infrastructure.

### 4. Configure Variables

Edit `infra/live/dev/terraform.tfvars`:

```hcl
# If you have an EC2 key pair for SSH access
key_name = "your-key-pair-name"

# If you want to use a specific VPC
# vpc_id = "vpc-xxxxxxxxx"
```

### 5. Deploy Infrastructure

#### Option A: Using GitHub Actions (Recommended)

1. Push your changes to the `main` branch
2. GitHub Actions will automatically build and deploy
3. Check the Actions tab for deployment status
4. Get outputs from the Terraform apply step

#### Option B: Manual Deployment

```bash
cd infra/live/dev

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the changes
terraform apply -auto-approve

# Get the outputs
terraform output
```

### 6. Configure the Frontend

After deployment, you'll get these outputs:

- `lambda_api_url`: Your API Gateway endpoint
- `static_site_url`: Your S3 website URL
- `ec2_public_ip`: Your EC2 instance IP

1. Visit the static site URL
2. In the Configuration section, enter your Lambda API URL
3. Test the API health check
4. Start triggering jobs!

## 📊 Usage

### Triggering Jobs

The portal supports several job types:

- **CI Pipeline**: Simulates continuous integration
- **Database Backup**: Mock backup operations
- **Deployment**: Application deployments
- **Security Scan**: Security assessments
- **Resource Cleanup**: Infrastructure maintenance

### API Endpoints

The Lambda API provides:

- `GET /health` - Health check
- `GET /jobs` - List job history
- `POST /jobs/trigger?type=<job_type>` - Trigger new job

### EC2 Worker Service

The EC2 instance runs a Go application that can be extended for:

- Long-running cron jobs
- Database monitoring
- Log aggregation
- Custom background processes

## 🔒 Security Features

- IAM roles with least privilege
- VPC security groups
- Encrypted EBS volumes
- HTTPS endpoints
- CORS configuration

## 🧪 Testing

Test the deployment:

```bash
# Test API directly
curl https://your-api-gateway-url/dev/health

# Test job triggering
curl -X POST "https://your-api-gateway-url/dev/jobs/trigger?type=ci"

# SSH to EC2 (if key pair configured)
ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip>
```

### Manual Testing Workflows

1. **Test Deploy Workflow**:
   ```bash
   # Create a feature branch
   git checkout -b test-feature
   
   # Make a small change
   echo "# Test change" >> infra/live/dev/terraform.tfvars
   
   # Push and create PR
   git add . && git commit -m "Test infrastructure change"
   git push origin test-feature
   ```

2. **Test Destroy Workflow**:
   - Navigate to Actions → Destroy Infrastructure
   - Select "dev" environment
   - Type "destroy" to confirm
   - Review and approve the destruction

3. **Test Drift Detection**:
   - Navigate to Actions → Infrastructure Drift Detection
   - Click "Run workflow"
   - Review the drift detection results

## 🔄 GitOps Workflow

The project includes four GitHub Actions workflows following [HashiCorp's best practices](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions):

### 1. **Smart GitOps Workflow** (`.github/workflows/gitops-smart.yml`) 🆕
- **Trigger**: Push to `main` branch, Manual dispatch
- **Key Feature**: **Commit message driven automation!**
- **How it works**: Analyzes commit messages to determine what action to take

**Commit Message Conventions:**
```bash
# Deploy to dev (default) !!!
git commit -m "feat: add new Lambda endpoint"

# Deploy to specific environment !!!!! 
git commit -m "feat: add metrics [deploy] to staging"

# Plan only (no apply)  !!
git commit -m "test: update configuration [plan]"

# Destroy (requires CONFIRM_DESTROY for safety)
git commit -m "[destroy] remove test resources CONFIRM_DESTROY"

# Destroy production (requires manual approval even with CONFIRM_DESTROY)
git commit -m "[destroy] cleanup prod resources CONFIRM_DESTROY"
```

**Safety Features:**
- **Safe destroys**: Require `CONFIRM_DESTROY` in commit message
- **Production protection**: Production destroys always require manual approval
- **Environment detection**: Automatically detects target environment from commit message
- **Commit status**: Updates GitHub commit status with deployment results

**Examples:**
```bash
# ✅ Deploy new feature to dev
git commit -m "feat: add job scheduling feature"

# ✅ Deploy to staging
git commit -m "feat: update API endpoints for staging"

# ✅ Safe destroy in dev
git commit -m "[destroy] remove old test resources CONFIRM_DESTROY"

# ⚠️ Production destroy (requires approval)
git commit -m "[destroy] cleanup prod CONFIRM_DESTROY"

# 📋 Plan only
git commit -m "test: infrastructure changes [plan]"
```

### 2. **Manual Deploy Workflow** (`.github/workflows/deploy.yml`)
- **Trigger**: Pull Requests (plan only), Manual dispatch
- **Purpose**: Manual infrastructure operations and PR previews
- **Features**:
  - Shows Terraform plan on Pull Requests
  - Manual deployment with environment selection
  - Choice between plan-only or apply
  - Useful for testing and custom operations

**Usage:**
- **PR Reviews**: Automatically shows plan when PRs modify infrastructure
- **Manual Deployment**: Go to Actions → Manual Deploy Infrastructure
- **Custom Operations**: Select environment and action (plan/apply)

### 3. **Destroy Workflow** (`.github/workflows/destroy.yml`)
- **Trigger**: Manual dispatch only
- **Safety Features**:
  - Requires typing "destroy" to confirm
  - Environment selection (dev/staging/prod)
  - Shows destroy plan before execution
  - Requires manual approval via GitHub Environment protection
  - Creates detailed destruction summary

### 4. **Drift Detection Workflow** (`.github/workflows/drift-detection.yml`)
- **Trigger**: Scheduled (weekdays at 6 AM UTC) + Manual dispatch
- **Features**:
  - Detects infrastructure drift across environments
  - Creates GitHub Issues when drift is detected
  - Provides actionable remediation steps
  - Runs on multiple environments via matrix strategy

### Environment Protection

The workflows use GitHub Environment protection for safety:

- **`production`**: Required for apply operations
- **`destroy-{environment}`**: Required for destroy operations

Set up environment protection in GitHub:
1. Go to Settings → Environments
2. Create `production` environment
3. Add required reviewers
4. Enable deployment branches (main only)

## 📁 Project Structure

```
demo/
├── .github/workflows/     # GitHub Actions CI/CD
├── app/
│   ├── frontend/          # S3 static site
│   ├── lambda-jobs-api/   # Go Lambda function
│   └── ec2-worker-service/# Go EC2 application
├── infra/
│   ├── modules/           # Reusable Terraform modules
│   └── live/dev/          # Environment configuration
└── README.md
```

## 🛠️ Customization

### Adding New Job Types

1. Update the Lambda function in `app/lambda-jobs-api/main.go`
2. Add the job type to the frontend dropdown
3. Deploy via GitHub Actions

### Extending EC2 Worker

1. Modify `app/ec2-worker-service/main.go`
2. Update the user-data script if needed
3. Redeploy the infrastructure

### Adding Environments

1. Create new directories under `infra/live/`
2. Copy and modify the dev configuration
3. Update GitHub Actions workflow

## 🧹 Cleanup

To destroy all resources:

```bash
cd infra/live/dev
terraform destroy -auto-approve
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📚 Further Reading

- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Lambda Go](https://docs.aws.amazon.com/lambda/latest/dg/golang-handler.html)
- [GitOps Principles](https://www.gitops.tech/)

---

**Built with ❤️ for demonstrating modern GitOps practices**

## 🚀 Quick Start with Smart GitOps

The easiest way to use this project is with the **Smart GitOps workflow** that automatically detects your intent from commit messages:

### **Automatic Workflow Selection**

| Commit Message | Workflow Used | Result |
|----------------|---------------|--------|
| `feat: add new feature` | Smart GitOps | 🚀 Deploy to dev |
| `feat: update API for staging` | Smart GitOps | 🚀 Deploy to staging |
| `test: infrastructure changes [plan]` | Smart GitOps | 📋 Plan only |
| `[destroy] remove resources CONFIRM_DESTROY` | Smart GitOps | 🚨 Safe destroy |
| `PR with infra changes` | Manual Deploy | 📋 Plan comment on PR |
| Manual Actions button | Manual Deploy | 🔧 Custom operations |
