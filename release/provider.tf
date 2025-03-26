provider "aws" {
  region = var.Region

  default_tags {
    tags = {
      Environment = var.EnvTag
      Provisioner = "Terraform"
      Solution    = var.SolTag
    }
  }
}

# CloudFront/WAF provider
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.EnvTag
      Provisioner = "Terraform"
      Solution    = var.SolTag
    }
  }
}