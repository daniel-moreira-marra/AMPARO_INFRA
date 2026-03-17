resource "aws_s3_bucket" "media_bucket" {
  bucket = "amparo-media-storage"

  tags = {
    Name        = "Amparo Media Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "media_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.media_bucket,
    aws_s3_bucket_public_access_block.media_bucket,
  ]

  bucket = aws_s3_bucket.media_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  depends_on = [aws_s3_bucket_public_access_block.media_bucket]
  bucket     = aws_s3_bucket.media_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_bucket.arn}/*"
      },
    ]
  })
}

# ------------------------------------------------------------------------------
# IAM POLICY FOR BACKEND S3 ACCESS
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "s3_access_policy" {
  name        = "amparo-s3-access-policy"
  description = "Permite que o backend acesse e escreva no bucket S3 de mídias"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.media_bucket.arn,
          "${aws_s3_bucket.media_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name # Referência dinâmica ao recurso em ecs.tf
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_s3_bucket_cors_configuration" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"] # Ajustar conforme necessário para segurança
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
