# sample-developer-environment

THIS REPO IS NOW PUBLIC: https://github.com/aws-samples/sample-developer-environment

This solution deploys a complete browser-based development environment with VS Code, version control, and automated deployments using a single AWS CloudFormation template.

## Repository Structure

```
.
├── dev/                              # Development workspace
│   └── README.md                     # Development guide
├── release/                          # Sample Terraform application
│   ├── main.tf                       # Core infrastructure
│   ├── provider.tf                   # AWS provider configuration
│   ├── variables.tf                  # Input variables
│   ├── versions.tf                   # Provider versions and backend
│   ├── website.tf                    # Sample static website
│   └── terraform.tfvars              # Variable defaults
└── sample-developer-environment.yml  # Main CloudFormation template
```

## Key Features

- Browser-based VS Code using [code-server](https://github.com/coder/code-server) accessed through Amazon CloudFront
- Git version control using [git-remote-s3](https://github.com/awslabs/git-remote-s3) with Amazon S3 storage
- Automated deployments using AWS CodePipeline and AWS CodeBuild
- Password rotation using AWS Secrets Manager (30-day automatic rotation)
- Pre-configured AWS development environment:
  - AWS Toolkit for VS Code
  - Terraform infrastructure deployment
  - Docker support
  - Git integration

## Quick Start

1. Launch the AWS CloudFormation template `sample-developer-environment.yml`
2. Access VS Code through the provided CloudFormation output URL
3. Get your password from AWS Secrets Manager (link in outputs)
4. Click *File* > *Open Folder* and navigate to `/home/ec2-user/my-workspace`. This is the git-initialized project directory
5. Start developing in the `dev` directory
6. Push tested code to `release` to trigger automated deployment


## Configuration Options

- `CodeServerVersion` - Version of code-server to install
- `GitHubRepo` - Public repository to clone as initial workspace
- `DeployPipeline` - Enable AWS CodePipeline deployments  
- `RotateSecret` - Enable AWS Secrets Manager rotation
- `InstanceType` - Supports both ARM and x86 Amazon EC2 instances

## Architecture

The environment runs in a private subnet with CloudFront access, using S3 for git storage and automated deployments.

![Architecture Diagram](img/architecture.png)

## Sample Application

The repository includes a Terraform application that deploys:
- Static website hosted on Amazon S3
- Amazon CloudFront distribution with AWS WAF protection
- Security headers and AWS KMS encryption
- Amazon CloudWatch logging

![Sample Application](img/sampleapplication.png)

The application deploys automatically when you set the CloudFormation parameter `DeployPipeline` to true. Once deployment completes, you can locate the website URL in the final output of the CodeBuild job.

⚠️ **WARNING**: Before removing the CloudFormation stack, ensure you run the destroy pipeline first. Failing to do so will leave orphaned resources in your AWS account that will need to be cleaned up manually.

## Security Considerations

⚠️ **IMPORTANT**: This sample uses HTTP for internal traffic between the Application Load Balancer and code-server Amazon EC2 instance. While external traffic is secured through CloudFront HTTPS, it is strongly recommended to:
- Configure end-to-end HTTPS using custom SSL certificates on the ALB
- Update ALB listener and target group to use HTTPS/443
- Use a custom domain name with AWS Certificate Manager (ACM) certificates

See [line 670](sample-developer-environment.yml#L670) in the CloudFormation template for more details on this design decision and implementation guidance.



## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

## Disclaimer

**This repository is intended for demonstration and learning purposes only.**
It is **not** intended for production use. The code provided here is for educational purposes and should not be used in a live environment without proper testing, validation, and modifications.
Use at your own risk. The authors are not responsible for any issues, damages, or losses that may result from using this code in production.