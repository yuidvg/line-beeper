variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "domain" {
  description = "Domain for Matrix server (e.g., matrix.example.com)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_password" {
  description = "PostgreSQL password for Synapse"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}
