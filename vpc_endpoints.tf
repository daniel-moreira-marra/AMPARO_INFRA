# ==============================================================================
# VPC ENDPOINTS (ECR + S3 + CloudWatch Logs)
# ==============================================================================
# Permite que as tasks do ECS no Fargate se comuniquem com a AWS sem sair para
# a internet pública. É necessário para ambientes sem NAT Gateway.

# Security Group para os VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "amparo_vpc_endpoints_sg"
  description = "Permite HTTPS de dentro da VPC para os endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = { Name = "amparo-vpc-endpoints-sg" }
}

# Endpoint para autenticação do ECR (obrigatório para o Fargate puxar imagens)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = { Name = "amparo-ecr-api-endpoint" }
}

# Endpoint para transferência de camadas de imagem Docker do ECR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = { Name = "amparo-ecr-dkr-endpoint" }
}

# Endpoint para o S3 (usado para transferir as camadas das imagens ECR)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  tags = { Name = "amparo-s3-endpoint" }
}

# Endpoint para o CloudWatch Logs (para os logs dos containers)
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = { Name = "amparo-cloudwatch-logs-endpoint" }
}
