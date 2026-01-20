# NixOS AMI (official ARM)
data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"] # NixOS official

  filter {
    name   = "name"
    values = ["nixos/25.05*-aarch64-linux"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "line-beeper-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "matrix" {
  ami                    = data.aws_ami.nixos.id
  instance_type          = "t4g.small"
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

  user_data = <<-EOF
    #!/run/current-system/sw/bin/bash
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
