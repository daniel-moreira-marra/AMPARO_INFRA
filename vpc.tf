# ==============================================================================
# VIRTUAL PRIVATE CLOUD (VPC)
# ==============================================================================
# Cria a rede virtual privada principal onde os recursos da aplicação "amparo" irão residir.
# O bloco CIDR "10.0.0.0/16" fornece um range de até 65.536 endereços IP privados.
# 'enable_dns_hostnames = true' garante que os recursos na rede recebam nomes DNS.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "amparo-vpc"
  }
}

# ==============================================================================
# INTERNET GATEWAY (IGW)
# ==============================================================================
# Permite que os recursos dentro da VPC (como instâncias nas sub-redes públicas)
# tenham acesso à internet e que a internet possa acessar os recursos expostos.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "amparo-gateway"
  }
}

# ==============================================================================
# SUB-REDES (SUBNETS)
# ==============================================================================

# Sub-rede Primária (us-east-1a)
# 'map_public_ip_on_launch = true' faz com que os recursos lançados aqui (como EC2) 
# ganhem um IP público automaticamente, tornando-os acessíveis pela web.
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

# Sub-rede Secundária (us-east-1b)
# Adiciona Alta Disponibilidade (Multi-AZ): se a zona de disponibilidade A (Prédio A) 
# falhar por algum motivo, a aplicação pode ser servida a partir desta zona B.
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b" # Prédio B (Para o sistema não cair se o A falhar)
}