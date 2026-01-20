# LINE-Beeper

Matrix Synapse + LINE bridge on AWS, fully declarative with Terraform and NixOS.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    VPC                               │    │
│  │  ┌─────────────────────────────────────────────────┐    │
│  │  │              EC2 (NixOS)                         │    │
│  │  │  ┌─────────────┐  ┌───────────────────────┐     │    │
│  │  │  │   Nginx     │  │  matrix-puppeteer-    │     │    │
│  │  │  │  (SSL/TLS)  │  │  line-chrome          │     │    │
│  │  │  └──────┬──────┘  │  (Puppeteer+Chrome)   │     │    │
│  │  │         │         └───────────┬───────────┘     │    │
│  │  │         ▼                     │                 │    │
│  │  │  ┌─────────────┐              │                 │    │
│  │  │  │   Synapse   │◄─────────────┘                 │    │
│  │  │  │  (Matrix)   │                                │    │
│  │  │  └──────┬──────┘                                │    │
│  │  └─────────┼───────────────────────────────────────┘    │
│  │            │                                             │
│  │            ▼                                             │
│  │  ┌─────────────────┐                                    │
│  │  │  RDS PostgreSQL │                                    │
│  │  └─────────────────┘                                    │
│  └─────────────────────────────────────────────────────────┘
│                                                              │
│  ┌─────────────┐                                            │
│  │  KMS (SOPS) │  ← Secrets encryption                      │
│  └─────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Beeper/Element │
                    │    (Client)     │
                    └─────────────────┘
```

## Prerequisites

- AWS account with appropriate permissions
- Domain with Route53 hosted zone
- Nix with flakes enabled
- LINE account on smartphone

## Quick Start

### 1. Clone and enter dev shell

```bash
git clone https://github.com/yuidvg/line-beeper.git
cd line-beeper
nix develop
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Update SOPS configuration

After `terraform apply`, update `.sops.yaml` with the KMS ARN:

```bash
# Get KMS ARN
terraform output kms_key_arn

# Update .sops.yaml with the ARN
```

### 5. Create secrets

```bash
# Create encrypted secrets file
sops secrets/secrets.yaml
```

Add the following secrets:
- `db_password`: PostgreSQL password (same as terraform.tfvars)
- `matrix_registration_shared_secret`: Random string for Matrix registration
- `line_bridge_secret`: Random string for bridge

### 6. Deploy NixOS configuration

```bash
# From project root
nixos-rebuild switch --flake .#line-beeper \
  --target-host root@$(terraform -chdir=terraform output -raw instance_public_ip)
```

### 7. Download LINE Chrome extension

On the server:

```bash
# Download LINE extension (version 2.5.0)
# Use CRX Extractor or manual download
# Extract to /var/lib/matrix-puppeteer-line/extension_files/
```

### 8. Start bridge and login

```bash
# Restart services
systemctl restart matrix-puppeteer-line-chrome
systemctl restart matrix-puppeteer-line

# Login via Matrix client
# Start a chat with @linebot:your.domain
# Use !line login-qr or !line login-email
```

## Directory Structure

```
line-beeper/
├── flake.nix                 # Nix flake definition
├── flake.lock
├── .sops.yaml                # SOPS configuration
├── secrets/
│   └── secrets.yaml          # Encrypted secrets (git-tracked)
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── ec2.tf
│   ├── rds.tf
│   ├── dns.tf
│   ├── kms.tf
│   ├── iam.tf
│   └── outputs.tf
└── nix/
    ├── modules/
    │   ├── hardware-aws.nix
    │   ├── synapse.nix
    │   └── matrix-puppeteer-line.nix
    └── packages/
        ├── matrix-puppeteer-line.nix
        └── matrix-puppeteer-line-chrome.nix
```

## Secrets Management

This project uses SOPS with AWS KMS for secrets management.

### How it works

1. Secrets are encrypted locally using KMS
2. Encrypted files are committed to Git
3. EC2 instance decrypts secrets at runtime via IAM role
4. No private keys stored locally or in Git

### Adding new secrets

```bash
# Edit secrets (auto-decrypts/encrypts)
sops secrets/secrets.yaml

# Add new secret in NixOS module
sops.secrets."new_secret" = {
  owner = "service-user";
};
```

## Limitations

- **matrix-puppeteer-line is unmaintained** (last update: 4 years ago)
- LINE Chrome extension version dependency
- Requires manual LINE extension download
- LINE account may be banned for using unofficial clients

## Troubleshooting

### Bridge not connecting

```bash
journalctl -u matrix-puppeteer-line -f
journalctl -u matrix-puppeteer-line-chrome -f
```

### Synapse issues

```bash
journalctl -u matrix-synapse -f
```

### SOPS decryption fails

Ensure EC2 instance has IAM role with KMS decrypt permission:

```bash
aws sts get-caller-identity  # Check IAM role
```

## License

AGPL-3.0-or-later (following matrix-puppeteer-line)
