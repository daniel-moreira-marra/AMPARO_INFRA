# ==============================================================================
# ELASTIC CONTAINER SERVICE (ECS) - FARGATE
# ==============================================================================

# Data source para obter o ID da conta AWS dinamicamente
data "aws_caller_identity" "current" {}

# 1. Cluster ECS (agrupador lógico)
resource "aws_ecs_cluster" "main" {
  name = "amparo-cluster"
  tags = { Name = "amparo-cluster" }
}

# 2. IAM Role para as Tasks (permissão para puxar imagem do ECR e enviar logs)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "amparo-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permissões extras para o ECS Execute Command (SSM)
resource "aws_iam_policy" "ecs_execute_command" {
  name        = "amparo-ecs-execute-command-policy"
  description = "Permite que as tasks do ECS usem o ExecuteCommand (SSM)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execute_command_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execute_command.arn
}

# 3. Log Groups no CloudWatch
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/amparo-backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/amparo-frontend"
  retention_in_days = 14
}

# ==============================================================================
# TASK DEFINITIONS
# ==============================================================================

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = "us-east-1"
  ecr_base_url   = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com"
}

# Task Definition do Backend (Django + Gunicorn)
resource "aws_ecs_task_definition" "backend" {
  family                   = "amparo-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${local.ecr_base_url}/amparo-backend-repo:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DJANGO_SETTINGS_MODULE", value = "backend.settings.prod" },
        { name = "DEBUG",                  value = var.debug },
        { name = "POSTGRES_DB",            value = var.db_name },
        { name = "POSTGRES_USER",          value = var.db_username },
        { name = "POSTGRES_PASSWORD",      value = var.db_password },
        { name = "POSTGRES_HOST",          value = var.db_host },
        { name = "POSTGRES_PORT",          value = "5432" },
        { name = "DJANGO_SECRET_KEY",      value = var.django_secret_key },
        { name = "DJANGO_ALLOWED_HOSTS",   value = var.allowed_hosts },
        { name = "AWS_ACCESS_KEY_ID",      value = var.aws_access_key_id },
        { name = "AWS_SECRET_ACCESS_KEY",  value = var.aws_secret_access_key },
        { name = "AWS_STORAGE_BUCKET_NAME",value = var.aws_bucket_name },
        { name = "AWS_S3_REGION_NAME",     value = local.aws_region },
        { name = "DJANGO_ALLOWED_CORS",    value = var.django_allowed_cors },
        { name = "CSRF_TRUSTED_ORIGINS",   value = var.csrf_trusted_origins },
        { name = "IS_ADMIN_BLOCKED",       value = var.is_admin_blocked },
        { name = "DEVELOPMENT_ENVIRONMENT",value = var.development_environment },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Task Definition do Frontend (Nginx + Static files)
resource "aws_ecs_task_definition" "frontend" {
  family                   = "amparo-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${local.ecr_base_url}/amparo-frontend-repo:latest"
      essential = true
      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ==============================================================================
# ECS SERVICES
# ==============================================================================

# Service do Backend
resource "aws_ecs_service" "backend" {
  name            = "amparo-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true # Necessário para Fargate puxar imagem do ECR sem NAT Gateway
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Service do Frontend
resource "aws_ecs_service" "frontend" {
  name            = "amparo-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ==============================================================================
# AUTO SCALING
# ==============================================================================

# Scalable Target para o Backend
resource "aws_appautoscaling_target" "backend" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Política de Escalonamento por CPU - Backend (70%)
resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "amparo-backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Política de Escalonamento por Memória - Backend (70%)
resource "aws_appautoscaling_policy" "backend_memory" {
  name               = "amparo-backend-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Scalable Target para o Frontend
resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Política de Escalonamento por CPU - Frontend (70%)
resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "amparo-frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Política de Escalonamento por Memória - Frontend (70%)
resource "aws_appautoscaling_policy" "frontend_memory" {
  name               = "amparo-frontend-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
