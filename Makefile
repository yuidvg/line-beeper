.PHONY: deploy infra nixos init plan destroy clean ssh status

# SSH key path (override with SSH_KEY=path)
SSH_KEY ?= ~/.ssh/line-beeper

# Full deployment: infrastructure + NixOS configuration
deploy: infra nixos
	@echo "✓ Deployment complete!"
	@echo "  Domain: https://yuidvg.click"
	@echo "  SSH: make ssh"

# Initialize Terraform
init:
	cd terraform && terraform init

# Plan infrastructure changes
plan: init
	cd terraform && terraform plan

# Apply infrastructure only (EC2, DNS, KMS)
infra: init
	cd terraform && terraform apply -auto-approve
	@echo "Waiting 30s for instance to initialize..."
	@sleep 30

# Deploy NixOS configuration
# Builds on remote ARM host, then switches
nixos:
	@IP=$$(cd terraform && terraform output -raw instance_public_ip 2>/dev/null); \
	if [ -z "$$IP" ]; then \
		echo "Error: No instance IP found. Run 'make infra' first."; \
		exit 1; \
	fi; \
	echo "Deploying NixOS to $$IP (building on remote)..."; \
	NIX_SSHOPTS="-o StrictHostKeyChecking=no -i $(SSH_KEY)" \
	nix run nixpkgs#nixos-rebuild -- switch \
		--flake .#line-beeper \
		--target-host root@$$IP \
		--build-host root@$$IP

# Destroy all infrastructure
destroy:
	cd terraform && terraform destroy -auto-approve

# Clean local cache
clean:
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl

# SSH into the server
ssh:
	@IP=$$(cd terraform && terraform output -raw instance_public_ip); \
	ssh -i $(SSH_KEY) root@$$IP

# Show current state
status:
	@echo "=== Infrastructure ==="
	@cd terraform && terraform output 2>/dev/null || echo "Not deployed"
	@echo ""
	@echo "=== Service Status ==="
	@IP=$$(cd terraform && terraform output -raw instance_public_ip 2>/dev/null); \
	if [ -n "$$IP" ]; then \
		ssh -o ConnectTimeout=5 -i $(SSH_KEY) root@$$IP \
			"systemctl status matrix-synapse nginx --no-pager" 2>/dev/null || echo "Cannot connect"; \
	fi
