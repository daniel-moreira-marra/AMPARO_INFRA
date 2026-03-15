variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "amparo_db"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for the master DB user"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Endpoint do RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "django_secret_key" {
  description = "SECRET_KEY do Django"
  type        = string
  sensitive   = true
}

variable "allowed_hosts" {
  description = "DJANGO_ALLOWED_HOSTS (separado por vírgula)"
  type        = string
  default     = "*"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID para o backend acessar o S3"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key para o backend acessar o S3"
  type        = string
  sensitive   = true
}

variable "aws_bucket_name" {
  description = "Nome do novo bucket S3 para mídias"
  type        = string
}

variable "old_aws_bucket_name" {
  description = "Nome do bucket S3 antigo para migração"
  type        = string
  default     = "amparo-s3-instance"
}

variable "django_allowed_cors" {
  description = "DJANGO_ALLOWED_CORS"
  type        = string
  default     = "*"
}

variable "csrf_trusted_origins" {
  description = "CSRF_TRUSTED_ORIGINS"
  type        = string
  default     = "*"
}

variable "is_admin_blocked" {
  description = "IS_ADMIN_BLOCKED"
  type        = string
  default     = "False"
}

variable "debug" {
  description = "Modo debug do Django"
  type        = string
  default     = "False"
}

variable "development_environment" {
  description = "DEVELOPMENT_ENVIRONMENT"
  type        = string
  default     = "PROD"
}

