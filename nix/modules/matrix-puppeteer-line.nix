{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.matrix-puppeteer-line;
  pkg = pkgs.matrix-puppeteer-line;
  puppetPkg = pkg.puppet;

  configFile = pkgs.writeText "matrix-puppeteer-line-config.yaml" ''
    appservice:
        address: http://localhost:${toString cfg.port}
        hostname: 0.0.0.0
        port: ${toString cfg.port}
        max_body_size: 1
        database: postgres://matrix-puppeteer-line@localhost/matrix-puppeteer-line

        id: line
        bot_username: linebot
        bot_displayname: LINE bridge bot
        bot_avatar: mxc://miscworks.net/vkVOqyfLTQTfRvlEgEoampPW

        community_id: false

        as_token: "{AS_TOKEN}"
        hs_token: "{HS_TOKEN}"

        # Enable provisioning API
        provisioning:
            enabled: true
            prefix: /_matrix/provision/v1
            shared_secret: generate

    bridge:
        username_template: "line_{userid}"
        displayname_template: "{displayname} (LINE)"
        displayname_max_length: 100
        initial_conversation_sync: 10
        invite_own_puppet_to_pm: false
        # login_shared_secret will be injected via envsubst
        login_shared_secret: "$MATRIX_REGISTRATION_SHARED_SECRET"
        federate_rooms: true
        backfill:
            disable_notifications: false
        encryption:
            allow: false
            default: false
            key_sharing:
                allow: false
                require_cross_signing: false
                require_verification: true
        private_chat_portal_meta: false
        delivery_receipts: false
        delivery_error_reports: false
        resend_bridge_info: false
        receive_stickers: true
        use_sticker_events: true
        emoji_scale_factor: 1
        command_prefix: "!line"
        user: "${cfg.adminUser}"

    puppeteer:
        connection:
            type: unix
            path: /var/run/matrix-puppeteer-line/puppet.sock

    logging:
        version: 1
        formatters:
            colored:
                (): matrix_puppeteer_line.util.ColorFormatter
                format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
        handlers:
            console:
                class: logging.StreamHandler
                formatter: colored
        loggers:
            mau:
                level: DEBUG
            aiohttp:
                level: INFO
        root:
            level: DEBUG
            handlers: [console]
  '';

  puppetConfigFile = pkgs.writeText "puppet-config.json" ''
    {
        "listen": {
            "type": "unix",
            "path": "/var/run/matrix-puppeteer-line/puppet.sock"
        },
        "executable_path": "${pkgs.chromium}/bin/chromium",
        "profile_dir": "./profiles",
        "extension_dir": "./extension_files",
        "cycle_delay": 5000,
        "use_xdotool": false,
        "jiggle_delay": 20000,
        "devtools": false
    }
  '';

in
{
  options.services.matrix-puppeteer-line = {
    enable = mkEnableOption "matrix-puppeteer-line bridge";

    port = mkOption {
      type = types.int;
      default = 29394;
      description = "Port to listen on";
    };

    adminUser = mkOption {
      type = types.str;
      default = "@admin:yuidvg.click";
      description = "Admin user MXID";
    };

    dbPassword = mkOption {
      type = types.str;
      default = "matrix-puppeteer-line";
      description = "Database password (not used with peer auth)";
    };
  };

  config = mkIf cfg.enable {
    # App Service Config for Synapse
    services.matrix-synapse.settings.app_service_config_files = [
      "/var/lib/matrix-puppeteer-line/registration.yaml"
    ];

    # Database
    services.postgresql = {
      enable = true;
      ensureUsers = [
        {
          name = "matrix-puppeteer-line";
          # No passwordFile, using peer auth
        }
      ];
      ensureDatabases = [ "matrix-puppeteer-line" ];

      # Allow local peer authentication
      authentication = mkForce ''
        # TYPE  DATABASE                USER                    ADDRESS                 METHOD
        local   matrix-puppeteer-line   matrix-puppeteer-line                           peer
        local   all                     all                                             peer
        host    all                     all                     127.0.0.1/32            trust
        host    all                     all                     ::1/128                 trust
      '';
    };

    # Systemd Service - Node.js (Puppeteer)
    systemd.services.matrix-puppeteer-line-chrome = {
      description = "Chrome/Puppeteer backend for matrix-puppeteer-line";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.chromium ];

      serviceConfig = {
        User = "matrix-puppeteer-line";
        Group = "matrix-puppeteer-line";
        WorkingDirectory = "/var/lib/matrix-puppeteer-line/puppet";
        RuntimeDirectory = "matrix-puppeteer-line";

        # Setup symlinks for read-only source files
        ExecStartPre = pkgs.writeShellScript "setup-puppet" ''
          mkdir -p /var/lib/matrix-puppeteer-line/puppet
          cd /var/lib/matrix-puppeteer-line/puppet

          # Link src directory
          rm -rf src
          ln -sf ${puppetPkg}/libexec/matrix-puppeteer-line/deps/matrix-puppeteer-line/puppet/src src

          # Link node_modules
          rm -rf node_modules
          ln -sf ${puppetPkg}/libexec/matrix-puppeteer-line/deps/matrix-puppeteer-line/puppet/node_modules node_modules

          # Copy package.json just in case
          rm -f package.json
          cp ${puppetPkg}/libexec/matrix-puppeteer-line/deps/matrix-puppeteer-line/puppet/package.json .
        '';

        ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a ${pkgs.nodejs}/bin/node src/main.js --config ${puppetConfigFile}";
        Restart = "on-failure";
        RestartSec = 3;
      };

      environment = {
        # Ensure Puppeteer finds the bundled node_modules
        NODE_PATH = "${puppetPkg}/libexec/matrix-puppeteer-line/deps/matrix-puppeteer-line/puppet/node_modules";
        PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      };
    };

    # Systemd Service - Python (Main)
    systemd.services.matrix-puppeteer-line = {
      description = "matrix-puppeteer-line bridge";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "matrix-puppeteer-line-chrome.service"
        "postgresql.service"
      ];
      after = [
        "matrix-puppeteer-line-chrome.service"
        "postgresql.service"
      ];

      serviceConfig = {
        User = "matrix-puppeteer-line";
        Group = "matrix-puppeteer-line";
        StateDirectory = "matrix-puppeteer-line";
        WorkingDirectory = "/var/lib/matrix-puppeteer-line";
        RuntimeDirectory = "matrix-puppeteer-line";
        RequiresMountsFor = "/var/lib/matrix-puppeteer-line";
      };

      script = ''
        # Ensure configuration
        export MATRIX_REGISTRATION_SHARED_SECRET=$(cat /run/secrets/matrix_registration_shared_secret)

        ${pkgs.gettext}/bin/envsubst < ${configFile} > config.yaml

        # Generate registration if missing
        if [ ! -f registration.yaml ]; then
          ${pkg}/bin/matrix-puppeteer-line -g -c config.yaml -r registration.yaml
          # Force restart Synapse on new registration?
          # Or trust that colmena will restart synapse if app_service_config_files changed?
          # The file content is dynamic, so nix doesn't know.
          # We might need to restart manually once.
        else
          # Update tokens in config.yaml from existing registration.yaml
          AS_TOKEN=$(grep 'as_token:' registration.yaml | awk '{print $2}' | tr -d '"')
          HS_TOKEN=$(grep 'hs_token:' registration.yaml | awk '{print $2}' | tr -d '"')

          # Use temp file for sed to avoid issues
          sed "s/{AS_TOKEN}/$AS_TOKEN/" config.yaml > config.yaml.tmp && mv config.yaml.tmp config.yaml
          sed "s/{HS_TOKEN}/$HS_TOKEN/" config.yaml > config.yaml.tmp && mv config.yaml.tmp config.yaml
        fi

        # Run
        exec ${pkg}/bin/matrix-puppeteer-line -c config.yaml
      '';
    };

    users.users.matrix-puppeteer-line = {
      isSystemUser = true;
      group = "matrix-puppeteer-line";
      home = "/var/lib/matrix-puppeteer-line";
      createHome = true;
    };

    users.groups.matrix-puppeteer-line = { };
  };
}
