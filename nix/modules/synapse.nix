{ config, lib, pkgs, ... }:

let
  cfg = config.services.line-beeper;
in
{
  options.services.line-beeper = {
    enable = lib.mkEnableOption "LINE-Beeper Matrix server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Matrix server domain";
      example = "matrix.example.com";
    };

    dbHost = lib.mkOption {
      type = lib.types.str;
      description = "PostgreSQL host (RDS endpoint)";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email for Let's Encrypt";
    };
  };

  config = lib.mkIf cfg.enable {
    # SOPS secrets
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      
      secrets = {
        "db_password" = {
          owner = "matrix-synapse";
          group = "matrix-synapse";
        };
        "matrix_registration_shared_secret" = {
          owner = "matrix-synapse";
          group = "matrix-synapse";
        };
      };
    };

    # Matrix Synapse
    services.matrix-synapse = {
      enable = true;
      settings = {
        server_name = cfg.domain;
        public_baseurl = "https://${cfg.domain}";

        listeners = [
          {
            port = 8008;
            bind_addresses = [ "127.0.0.1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [ "client" "federation" ];
                compress = true;
              }
            ];
          }
        ];

        database = {
          name = "psycopg2";
          args = {
            host = cfg.dbHost;
            database = "synapse";
            user = "synapse";
            cp_min = 5;
            cp_max = 10;
          };
        };

        # Federation
        enable_registration = false;
        allow_guest_access = false;

        # App services (bridge)
        app_service_config_files = [
          "/var/lib/matrix-synapse/line-registration.yaml"
        ];
      };

      # Extra config file for secrets
      extraConfigFiles = [
        "/run/secrets/synapse-extra-config"
      ];
    };

    # Generate extra config with secrets at runtime
    sops.templates."synapse-extra-config" = {
      owner = "matrix-synapse";
      content = ''
        database:
          args:
            password: "${config.sops.placeholder."db_password"}"
        registration_shared_secret: "${config.sops.placeholder."matrix_registration_shared_secret"}"
      '';
    };

    # Nginx reverse proxy
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts."${cfg.domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8008";
          proxyWebsockets = true;
        };

        locations."/.well-known/matrix/server" = {
          return = "200 '{\"m.server\": \"${cfg.domain}:443\"}'";
          extraConfig = ''
            add_header Content-Type application/json;
          '';
        };

        locations."/.well-known/matrix/client" = {
          return = "200 '{\"m.homeserver\": {\"base_url\": \"https://${cfg.domain}\"}}'";
          extraConfig = ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };
      };
    };

    # ACME (Let's Encrypt)
    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.acmeEmail;
    };

    # Ensure synapse restarts when secrets change
    systemd.services.matrix-synapse = {
      serviceConfig = {
        ExecStartPre = [
          "${pkgs.coreutils}/bin/sleep 2"  # Wait for secrets
        ];
      };
    };
  };
}
