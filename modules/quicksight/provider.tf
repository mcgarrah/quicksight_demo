terraform {

  required_version = ">= 1.5"
  backend "http" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.16.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.3"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      application = "quicksight-demo"
      git_repo    = "https://github.com/mcgarrah/quicksight_demo"
    }
  }

}
