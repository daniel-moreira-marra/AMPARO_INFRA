# ==============================================================================
# IAM USER FOR BACKEND S3 ACCESS
# ==============================================================================

# 1. Criação do Usuário IAM para o Backend
resource "aws_iam_user" "backend_s3_user" {
  name = "amparo-backend-s3-user"
  tags = { Name = "amparo-backend-s3-user" }
}

# 2. Geração das Chaves de Acesso (Access Key e Secret Key)
resource "aws_iam_access_key" "backend_s3_key" {
  user = aws_iam_user.backend_s3_user.name
}

# 3. Anexando a Política S3 Full Access ao Usuário
resource "aws_iam_user_policy_attachment" "s3_full_access" {
  user       = aws_iam_user.backend_s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
