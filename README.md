# LINE-Beeper

Matrix Synapse + LINE bridge on AWS, deployed declaratively with Terraform + Colmena.

## Quick Start

```bash
# Clone
git clone https://github.com/yuidvg/line-beeper.git
cd line-beeper

# Configure (one-time)
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars  # Fill in your values

# Deploy (idempotent - safe to run multiple times)
make deploy
```

That's it. `make deploy` handles everything: infrastructure, DNS, SSL, and NixOS configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ AWS (ap-northeast-1)                                        │
│                                                             │
│  Route53 (yuidvg.click)                                     │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ EC2 (t4g.small, ARM, ~$12/month)                        ││
│  │  ├─ NixOS 24.05                                         ││
│  │  ├─ Matrix Synapse (SQLite)                             ││
│  │  ├─ Nginx + Let's Encrypt                               ││
│  │  └─ matrix-puppeteer-line (TODO)                        ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  KMS ─── SOPS secrets (decrypted via IAM role)              │
└─────────────────────────────────────────────────────────────┘
```

## Commands

| Command | Description |
|---------|-------------|
| `make deploy` | Full deployment (Terraform + Colmena) |
| `make infra` | Infrastructure only |
| `make nixos` | NixOS config only (via Colmena) |
| `make plan` | Preview Terraform changes |
| `make destroy` | Tear down everything |
| `make ssh` | SSH into the server |
| `make status` | Show current state |

## Idempotency

This project is designed to be fully idempotent and stateless:

- **Terraform**: Declarative infrastructure
- **Colmena**: Stateless NixOS deployment, converges to `flake.lock`
- **SOPS + KMS**: Secrets encrypted in Git, decrypted at runtime

Running `make deploy` multiple times is safe.

## Directory Structure

```
.
├── flake.nix                 # Nix flake with Colmena hive
├── Makefile                  # Deployment commands
├── terraform/
│   ├── ec2.tf                # ARM instance
│   ├── vpc.tf                # Network
│   ├── dns.tf                # Route53
│   ├── kms.tf                # SOPS key
│   └── iam.tf                # Instance role
├── nix/modules/
│   ├── hardware-aws.nix      # AWS config
│   ├── synapse.nix           # Matrix server
│   └── matrix-puppeteer-line.nix  # LINE bridge
└── secrets/
    └── secrets.yaml          # SOPS-encrypted
```

## Secrets

```bash
# Edit (requires AWS KMS access)
sops secrets/secrets.yaml
```

## Limitations

- matrix-puppeteer-line is unmaintained (4+ years)
- LINE may ban accounts using unofficial clients

## License

MIT
