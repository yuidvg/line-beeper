resource "aws_iam_role" "matrix" {
  name = "line-beeper-matrix-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "line-beeper-matrix-role"
  }
}

resource "aws_iam_role_policy" "matrix_kms" {
  name = "line-beeper-kms-decrypt"
  role = aws_iam_role.matrix.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.sops.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "matrix" {
  name = "line-beeper-matrix-profile"
  role = aws_iam_role.matrix.name
}
