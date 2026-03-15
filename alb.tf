# ==============================================================================
# APPLICATION LOAD BALANCER (ALB)
# ==============================================================================

# Security Group do ALB - Abre a porta 80 para a internet
resource "aws_security_group" "alb_sg" {
  name        = "amparo_alb_sg"
  description = "Permite trafego HTTP para o Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "amparo-alb-sg" }
}

# Security Group dos containers ECS - só aceita tráfego vindo do ALB
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "amparo_ecs_tasks_sg"
  description = "Permite trafego apenas do ALB para os containers ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "amparo-ecs-tasks-sg" }
}

# O Load Balancer em si (fica nas subnets PÚBLICAS)
resource "aws_lb" "main" {
  name               = "amparo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "amparo-alb" }
}

# Target Group do Frontend (encaminha para a porta 80)
resource "aws_lb_target_group" "frontend" {
  name        = "amparo-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 120
    timeout             = 5
    matcher             = "200"
  }
}

# Target Group do Backend (encaminha para a porta 8000)
resource "aws_lb_target_group" "backend" {
  name        = "amparo-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/v1/health/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 120
    timeout             = 5
    matcher             = "200"
  }
}

# Listener na porta 80 - Regras de roteamento
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Ação padrão: encaminhar para o Frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Regra: Qualquer coisa em /api/* vai para o Backend
resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Output útil: exibe a URL do Load Balancer após o apply
output "alb_dns_name" {
  description = "URL pública do Load Balancer"
  value       = aws_lb.main.dns_name
}
