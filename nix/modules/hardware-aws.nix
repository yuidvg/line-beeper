{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  # Networking
  networking = {
    hostName = "line-beeper";
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
        80 # HTTP (ACME)
        443 # HTTPS
        8448 # Matrix federation
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

  # Enable line-beeper service
  services.line-beeper = {
    enable = true;
    domain = "yuidvg.click";
    acmeEmail = "student-earful.9r@icloud.com";
  };

  services.matrix-puppeteer-line.enable = true;

  # SOPS - secrets will be decrypted on the host
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.secrets.matrix_registration_shared_secret = {
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0440";
  };
  sops.secrets.line_bridge_secret = { };

  system.stateVersion = "24.05";
}
