{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  # EC2 specific settings
  ec2.hvm = true;

  # Boot
  boot.loader.grub.device = lib.mkForce "/dev/xvda";

  # Filesystem
  fileSystems."/" = {
    device = "/dev/xvda1";
    fsType = "ext4";
  };

  # Networking
  networking = {
    hostName = "line-beeper";
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22    # SSH
        80    # HTTP (ACME)
        443   # HTTPS
        8448  # Matrix federation
      ];
    };
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Time zone
  time.timeZone = "Asia/Tokyo";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    git
  ];

  system.stateVersion = "24.05";
}
