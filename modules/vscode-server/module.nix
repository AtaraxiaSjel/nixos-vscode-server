moduleConfig:
{ config, lib, pkgs, ... }:

{
  options.services.vscode-server = let
    inherit (lib) mkEnableOption mkOption literalExpression;
    inherit (lib.types) listOf nullOr package str bool;
  in {
    enable = mkEnableOption "VS Code Server";

    enableFHS = mkEnableOption "a FHS compatible environment";

    nodejsPackage = mkOption {
      type = nullOr package;
      default = null;
      example = pkgs.nodejs-16_x;
      description = ''
        Whether to use a specific Node.js rather than the version supplied by VS Code server.
      '';
    };

    extraRuntimeDependencies = mkOption {
      type = listOf package;
      default = [ ];
      description = ''
        A list of extra packages to use as runtime dependencies.
        It is used to determine the RPATH to automatically patch ELF binaries with,
        or when a FHS compatible environment has been enabled,
        to determine its extra target packages.
      '';
    };

    installPath = mkOption {
      type = str;
      default = "~/.vscode-server";
      example = "~/.vscode-server-oss";
      description = ''
        The install path.
      '';
    };

    extensions = mkOption {
      type = listOf package;
      default = [ ];
      example = literalExpression "[ pkgs.vscode-extensions.bbenoist.nix ]";
      description = ''
        The extensions Visual Studio Code should be started with.
      '';
    };

    immutableExtensionsDir = mkOption {
      type = bool;
      default = false;
      example = true;
      description = ''
        Whether extensions can be installed or updated manually
        by Visual Studio Code.
      '';
    };
  };

  config = let
    inherit (lib) mkDefault mkIf mkMerge;
    inherit (lib.strings) removePrefix;
    cfg = config.services.vscode-server;
  in mkIf cfg.enable (mkMerge [
    {
      services.vscode-server.nodejsPackage = mkIf cfg.enableFHS (mkDefault pkgs.nodejs-16_x);
    }
    (moduleConfig {
      name = "auto-fix-vscode-server";
      description = "Automatically fix the VS Code server used by the remote SSH extension";
      serviceConfig = {
        # When a monitored directory is deleted, it will stop being monitored.
        # Even if it is later recreated it will not restart monitoring it.
        # Unfortunately the monitor does not kill itself when it stops monitoring,
        # so rather than creating our own restart mechanism, we leverage systemd to do this for us.
        Restart = "always";
        RestartSec = 0;
        ExecStart = "${pkgs.callPackage ../../pkgs/auto-fix-vscode-server.nix (removeAttrs cfg [ "enable" ])}/bin/auto-fix-vscode-server";
      };
    })
  ]);
}
