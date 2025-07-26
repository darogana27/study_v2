# {{PRODUCT_NAME}}

This is a Terraform configuration for the {{PRODUCT_NAME}} product.

## Overview

This configuration includes the following AWS services:
- Lambda Functions
- S3 Buckets
- SQS Queues
- DynamoDB Tables
- ECR Repositories
- API Gateway (REST and HTTP)
- CloudFront
- EventBridge Scheduler
- Step Functions
- SNS Topics
- Parameter Store

## Region

This configuration is set up for the `{{REGION}}` region.

## Usage

1. Copy `terraform.tfvars.template` to `terraform.tfvars`
2. Uncomment and configure the resources you need
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Plan the deployment:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Configuration

Edit `terraform.tfvars` to configure the resources for your specific needs. Each resource type has example configurations commented out.

## File Structure

- `terraform.tf` - Provider configuration
- `main.tf` - Main module calls
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars` - Variable values (create from template)

## Notes

- All resources are tagged with the product name: `{{PRODUCT_NAME}}`
- Region is set to: `{{REGION}}`
- Modules are located in `../../modules/aws/`