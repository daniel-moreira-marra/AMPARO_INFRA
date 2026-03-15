terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Usa uma versão estável recente
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

