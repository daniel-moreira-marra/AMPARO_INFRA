# ==============================================================================
# RELATIONAL DATABASE SERVICE (RDS) - POSTGRESQL
# ==============================================================================

# 1. Grupo de Sub-redes do Banco de Dados
# O RDS exige que você informe em quais sub-redes (Zonas de Disponibilidade) 
# ele pode operar para fins de alta disponibilidade. Usamos as redes PRIVADAS.
resource "aws_db_subnet_group" "default" {
  name       = "amparo-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "Amparo DB subnet group"
  }
}

# 2. Security Group do Banco de Dados
# Regra de Firewall: Só permite acesso na porta 5432 vindo de dentro da VPC original
resource "aws_security_group" "rds_sg" {
  name        = "amparo_rds_sg"
  description = "Permite acesso ao PostgreSQL vindo apenas da VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "amparo-rds-sg"
  }
}

# 3. Instância do Banco de Dados (PostgreSQL 16)
resource "aws_db_instance" "postgres" {
  identifier           = "amparo-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "16"            # Versão sugerida, estável e moderna
  instance_class       = "db.t3.micro"   # Máquina barata (elegível a free-tier)
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot    = true          # Permite destruir o banco sem tirar backup final (bom para dev)
  publicly_accessible    = false         # O DB NÃO terá IP público

  tags = {
    Name = "Amparo PostgreSQL"
  }
}
