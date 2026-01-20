output "instance_public_ip" {
  description = "Public IP of the Matrix server"
  value       = aws_eip.matrix.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.matrix.id
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${aws_eip.matrix.public_ip}"
}

output "deploy_command" {
  description = "Command to deploy NixOS configuration"
  value       = "nixos-rebuild switch --flake .#line-beeper --target-host root@${aws_eip.matrix.public_ip}"
}

output "kms_key_arn" {
  description = "KMS key ARN for SOPS"
  value       = aws_kms_key.sops.arn
}

output "kms_key_alias" {
  description = "KMS key alias for SOPS"
  value       = aws_kms_alias.sops.name
}
