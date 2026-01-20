resource "aws_kms_key" "sops" {
  description             = "KMS key for SOPS secrets encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 Instance to Decrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.matrix.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "line-beeper-sops"
  }
}

resource "aws_kms_alias" "sops" {
  name          = "alias/line-beeper-sops"
  target_key_id = aws_kms_key.sops.key_id
}

data "aws_caller_identity" "current" {}
