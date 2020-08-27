provider "aws" {
  version = "~> 2.0"
  region = var.region
}

provider "template" {
  version = "~> 2"
}

