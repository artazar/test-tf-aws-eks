# AWS EKS Infrastructure

This project manages AWS infrastructure using Terraform and Terragrunt, deploying a complete EKS cluster environment with supporting resources.

## Infrastructure Components

When running `make apply`, the following infrastructure is deployed:

- **VPC** - Virtual Private Cloud with public and private subnets across multiple availability zones
- **EKS Cluster** - Amazon Elastic Kubernetes Service cluster with managed node groups
- **NGINX Demo App** - Sample web application deployed on EKS with AWS Load Balancer
- **Bastion Host** - EC2 instance for secure access to private resources (excluded by default)

All resources are deployed with proper networking, security groups, and IAM roles configured automatically.

Important: additional IAM users can be added to `aws_admin_users` array of EKS module values file to administer the cluster. The user applying the configuration is added by default.

## Prerequisites

- AWS credentials configured (via `aws configure` or environment variables)
  - See [AWS CLI Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) for detailed instructions
- S3 bucket created for storing Terraform state, add the bucket name to root.hcl configuration file
- `make` utility installed

## Getting Started

### Initial Bootstrap

TL;DR:

```
make apply
```

would deploy all infrastructure elements.

You will get the LB URL for deployed Nginx access as the final output (note: it may take 1-2 minutes to come up after the first run is over!)

---

For the cautious first time setup, follow these steps in order:

1. **Install required tools** (Terraform and Terragrunt):
   ```bash
   make install
   ```

2. **Initialize all modules**:
   ```bash
   make init
   ```

3. **Deploy VPC first** (required for other modules):
   ```bash
   make apply-module demo vpc
   ```

4. **Deploy EKS cluster**:
   ```bash
   make apply-module demo eks
   ```

5. **Deploy NGINX demo app**:
   ```bash
   make apply-module demo nginx
   ```

6. **Optional: Deploy bastion host**:
   ```bash
   make apply-module demo bastion
   ```

After deployment, get the NGINX public URL:
```bash
cd sites/demo/nginx && ../../../.bin/terragrunt output load_balancer_url
```

### Subsequent Deployments

After initial bootstrap, you can deploy all modules at once:

```bash
make apply
```

> **⚠️ Important:** Always run `make plan` first to review changes before applying. The `make apply` command runs with `-auto-approve` and **does not ask for confirmation** before making changes to your infrastructure.

## Available Commands

### Tool Installation
- `make install` - Install Terraform and Terragrunt locally in `.bin/` directory
- `make clean` - Remove locally installed tools

### Infrastructure Management
- `make init [demo]` - Initialize all modules for a site
- `make plan [demo]` - Show planned infrastructure changes
- `make apply [demo]` - Create or update infrastructure (**runs with `-auto-approve`**)
- `make destroy [demo]` - Destroy all infrastructure

### Per-Module Operations
You can also run commands on individual modules:
```bash
make init-module demo vpc
make plan-module demo eks
make apply-module demo nginx
make apply-module demo bastion
```

Available modules: `vpc`, `eks`, `nginx`, `bastion`

### Passing Extra Arguments
You can pass additional Terraform/Terragrunt arguments using `ARGS`:
```bash
make init ARGS="-upgrade"
make apply demo vpc ARGS="-auto-approve"
```

### Excluding Modules
If needed, some modules can be excluded from the run. You can customize this:
```bash
# Use default exclusions (bastion)
make apply

# Include all modules (no exclusions)
make apply EXCLUDE=""

# Exclude different modules
make apply EXCLUDE="bastion,eks"
```

## Project Structure

```
.
├── sites/
│   └── demo/           # Demo environment
│       ├── vpc/        # VPC module configuration
│       ├── eks/        # EKS cluster configuration
│       ├── nginx/      # NGINX demo app configuration
│       └── bastion/    # Bastion host configuration
├── modules/            # Reusable Terraform modules
├── root.hcl           # Root Terragrunt configuration
└── Makefile           # Build automation
```

## Notes

- All tools are installed locally in `.bin/` directory to avoid conflicts with system versions
- The default site is `demo`, but you can specify different sites as positional arguments
- Infrastructure state is stored in S3 backend (configured in `root.hcl`) and requires S3 bucket to exist first
- Dependencies between modules are handled automatically by Terragrunt
- The `bastion` module is excluded by default from `make apply` - deploy it explicitly when needed

## Known issues

- Each `make apply` produces changes to `helm_release.karpenter` and `helm_release.karpenter_crds` resources. This is the issue with the provided helm chart, unresolved as of today, related to updating OCI helm repo token. 
- Because of complicated dependency resolution scheme, `make destroy` may need to be run two times to clean up all resources completely.