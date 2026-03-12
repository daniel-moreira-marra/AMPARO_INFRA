terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Usa uma versão estável recente
    }
  }

  backend "s3" {
    bucket         = "nome-do-seu-bucket-de-estado" # Você precisa criar este bucket antes
    key            = "amparo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock" # Opcional: para evitar que dois deploys rodem ao mesmo tempo
  }
}

provider "aws" {
  region = "us-east-1"
}

