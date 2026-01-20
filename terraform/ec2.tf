# NixOS AMI (official)
data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"] # NixOS official

  filter {
    name   = "name"
    values = ["nixos/24.05*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "line-beeper-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "matrix" {
  ami                    = data.aws_ami.nixos.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.matrix.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.matrix.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "line-beeper-matrix"
  }

  # User data to bootstrap NixOS configuration
  user_data = <<-EOF
    #!/run/current-system/sw/bin/bash
    # Initial setup - actual config deployed via nixos-rebuild
    echo "NixOS instance ready for configuration"
  EOF
}

resource "aws_eip" "matrix" {
  instance = aws_instance.matrix.id
  domain   = "vpc"

  tags = {
    Name = "line-beeper-eip"
  }
}
