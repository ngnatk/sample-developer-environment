terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.38.0"
    }
  }
}

# Use Amazon S3 for Terraform backend
terraform {  
  backend "s3" {  
    key          = "terraform/statefile.tfstate"
    encrypt      = true
    use_lockfile = true  #S3 native locking
  }
}