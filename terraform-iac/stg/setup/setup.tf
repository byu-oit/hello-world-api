terraform {
  backend "s3" {
    bucket         = "terraform-state-storage-977306314792"
    dynamodb_table = "terraform-state-lock-977306314792"
    key            = "hw-fargate-api/stg/setup.tfstate"
    region         = "us-west-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

variable "some_secret" {
  type        = string
  description = "Some secret string that will be stored in SSM and mounted into the Fargate Tasks as an environment variable"
}

module "setup" {
  source      = "../../modules/setup/"
  env         = "stg"
  some_secret = var.some_secret
}
