{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.line-beeper;
in
{
  options.services.line-beeper = {
    enable = lib.mkEnableOption "LINE-Beeper Matrix server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Matrix server domain";
      example = "yuidvg.click";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email for Let's Encrypt";
      default = "admin@example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    # SOPS secrets
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;

      secrets = {
        "matrix_registration_shared_secret" = {
          owner = "matrix-synapse";
          group = "matrix-synapse";
        };
        "admin_password" = { };
      };
    };

    # Matrix Synapse with SQLite
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
                names = [
                  "client"
                  "federation"
                ];
                compress = true;
              }
            ];
          }
        ];

        # SQLite database (default, no config needed)
        database = {
          name = "sqlite3";
          args = {
            database = "/var/lib/matrix-synapse/homeserver.db";
          };
        };

        enable_registration = false;
        allow_guest_access = false;

        # App services (bridge) - will be added later
        # app_service_config_files = [];
      };

      extraConfigFiles = [
        config.sops.templates."synapse-extra-config".path
      ];
    };

    # Generate extra config with secrets at runtime
    sops.templates."synapse-extra-config" = {
      owner = "matrix-synapse";
      content = ''
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

    # Firewall
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    # Idempotent Admin User Creation
    systemd.services.matrix-synapse-register-admin = {
      description = "Register Matrix admin user idempotently";
      after = [ "matrix-synapse.service" ];
      wants = [ "matrix-synapse.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        # Wait for Synapse
        until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8008/health; do
          echo "Waiting for synapse..."
          sleep 5
        done

        ADMIN_PASS=$(cat ${config.sops.secrets."admin_password".path})
        SHARED_SECRET=$(cat ${config.sops.secrets."matrix_registration_shared_secret".path})

        # Create temp config for register tool
        CONF_FILE="/tmp/matrix-reg-config.yaml"
        echo "registration_shared_secret: $SHARED_SECRET" > "$CONF_FILE"
        chmod 600 "$CONF_FILE"

        # Attempt registration
        OUTPUT=$(${pkgs.matrix-synapse}/bin/register_new_matrix_user \
          -u admin \
          -p "$ADMIN_PASS" \
          -a \
          -c "$CONF_FILE" \
          http://127.0.0.1:8008 2>&1)
        RET=$?

        rm "$CONF_FILE"

        if [ $RET -eq 0 ]; then
          echo "Admin user created successfully."
        elif echo "$OUTPUT" | grep -q "User ID already taken"; then
          echo "Admin user already exists. Skipping."
        else
          echo "Failed to create admin user:"
          echo "$OUTPUT"
          exit 1
        fi
      '';
    };
  };
}
