terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.41"
    }
  }
  backend "s3" {
    bucket = "tfpocbucket001"
    key    = "eks/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region          = "ap-south-2"
  name            = "eks-cluster"
  vpc_cidr        = "10.112.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names))
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 1)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 7)]
  tags = {
    Name = local.name
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

output "update_kubeconfig_command" {
  value = format("aws eks update-kubeconfig --region %s --name %s", local.region, module.eks.cluster_name)
}

