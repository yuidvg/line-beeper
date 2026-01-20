{ config, lib, pkgs, self, ... }:

let
  cfg = config.services.matrix-puppeteer-line;
  bridgeCfg = config.services.line-beeper;
  
  # Package references
  matrix-puppeteer-line = self.packages.${pkgs.system}.matrix-puppeteer-line;
  matrix-puppeteer-line-chrome = self.packages.${pkgs.system}.matrix-puppeteer-line-chrome;
in
{
  options.services.matrix-puppeteer-line = {
    enable = lib.mkEnableOption "matrix-puppeteer-line bridge";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/matrix-puppeteer-line";
      description = "Data directory for the bridge";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "matrix-puppeteer-line";
      description = "User to run the bridge as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "matrix-puppeteer-line";
      description = "Group to run the bridge as";
    };

    matrixUser = lib.mkOption {
      type = lib.types.str;
      description = "Matrix user ID that can use the bridge";
      example = "@admin:example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    # SOPS secrets for bridge
    sops.secrets."line_bridge_secret" = {
      owner = cfg.user;
      group = cfg.group;
    };

    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.${cfg.group} = {};

    # Bridge config template
    sops.templates."matrix-puppeteer-line-config" = {
      owner = cfg.user;
      path = "${cfg.dataDir}/config.yaml";
      content = ''
        homeserver:
          address: https://${bridgeCfg.domain}
          domain: ${bridgeCfg.domain}
          verify_ssl: true

        appservice:
          address: http://localhost:29394
          hostname: 127.0.0.1
          port: 29394
          database: postgres://synapse:${config.sops.placeholder."db_password"}@${bridgeCfg.dbHost}/matrix_puppeteer_line
          id: line
          bot_username: linebot
          bot_displayname: LINE bridge bot

        bridge:
          username_template: "line_{userid}"
          displayname_template: "{displayname} (LINE)"
          command_prefix: "!line"
          user: "${cfg.matrixUser}"

        puppeteer:
          connection:
            type: unix
            path: /run/matrix-puppeteer-line/puppet.sock

        logging:
          version: 1
          formatters:
            normal:
              format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
          handlers:
            console:
              class: logging.StreamHandler
              formatter: normal
          root:
            level: INFO
            handlers: [console]
      '';
    };

    # Puppeteer config template
    sops.templates."matrix-puppeteer-line-chrome-config" = {
      owner = cfg.user;
      path = "${cfg.dataDir}/puppet-config.json";
      content = builtins.toJSON {
        listen = {
          type = "unix";
          path = "/run/matrix-puppeteer-line/puppet.sock";
        };
        executable_path = "${pkgs.chromium}/bin/chromium";
        extension_dir = "${cfg.dataDir}/extension_files";
        profile_dir = "${cfg.dataDir}/chrome-profile";
        devtools = false;
        cycle_delay = 5000;
      };
    };

    # Systemd service for Puppeteer module (Chrome)
    systemd.services.matrix-puppeteer-line-chrome = {
      description = "Matrix-LINE Puppeteer module";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        RuntimeDirectory = "matrix-puppeteer-line";
        RuntimeDirectoryMode = "0750";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${matrix-puppeteer-line-chrome}/bin/matrix-puppeteer-line-chrome --config ${cfg.dataDir}/puppet-config.json";
        Restart = "on-failure";
        RestartSec = 10;

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir "/run/matrix-puppeteer-line" ];
      };

      # Need xvfb for headless Chrome with extensions
      path = [ pkgs.xvfb-run ];
      preStart = ''
        # Ensure extension directory exists
        mkdir -p ${cfg.dataDir}/extension_files
        mkdir -p ${cfg.dataDir}/chrome-profile
      '';
    };

    # Systemd service for Bridge module (Python)
    systemd.services.matrix-puppeteer-line = {
      description = "Matrix-LINE bridge";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "matrix-puppeteer-line-chrome.service" "matrix-synapse.service" ];
      requires = [ "matrix-puppeteer-line-chrome.service" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${matrix-puppeteer-line}/bin/matrix-puppeteer-line --config ${cfg.dataDir}/config.yaml";
        Restart = "on-failure";
        RestartSec = 10;

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir "/run/matrix-puppeteer-line" ];
      };
    };

    # Generate appservice registration for Synapse
    systemd.services.matrix-puppeteer-line-registration = {
      description = "Generate Matrix-LINE bridge registration";
      wantedBy = [ "matrix-synapse.service" ];
      before = [ "matrix-synapse.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        RemainAfterExit = true;
      };

      script = ''
        if [ ! -f ${cfg.dataDir}/registration.yaml ]; then
          ${matrix-puppeteer-line}/bin/matrix-puppeteer-line \
            --config ${cfg.dataDir}/config.yaml \
            --generate-registration \
            --output ${cfg.dataDir}/registration.yaml
          
          # Copy to Synapse directory
          cp ${cfg.dataDir}/registration.yaml /var/lib/matrix-synapse/line-registration.yaml
          chown matrix-synapse:matrix-synapse /var/lib/matrix-synapse/line-registration.yaml
        fi
      '';
    };
  };
}
