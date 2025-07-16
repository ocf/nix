{ lib, config, ... }:

let
  cfg = config.ocf.github-actions;
  makeContainer = runner-cfg:
    let
      name = "ci-${runner-cfg.owner}-${runner-cfg.repo}-${runner-cfg.workflow}";
    in
    lib.mkIf runner-cfg.enable {
      ${name} = {
        ephemeral = true;
        autoStart = true;

        bindMounts = {
          "github-token" = {
            hostPath = runner-cfg.tokenPath;
            mountPoint = "/run/token";
            isReadOnly = true;
          };
        };
        config =
          { ... }:
          {
            nix.settings.experimental-features = "nix-command flakes";
            networking.firewall.enable = true;

            services.github-runners =
              builtins.listToAttrs (
                builtins.genList
                  (
                    i:
                    {
                      name = "${name}-${builtins.toString i}";
                      value = {
                        enable = true;
                        ephemeral = true;
                        user = null;
                        group = null;
                        replace = true;
                        noDefaultLabels = true;
                        extraLabels = [ name ];
                        url = "https://github.com/${runner-cfg.owner}/${runner-cfg.repo}";
                        tokenFile = "/run/token";
                        extraPackages = runner-cfg.packages;
                      };
                    }
                  )
                  runner-cfg.instances
              );
            system.stateVersion = "24.11";
          };
      };
    };


in
{
  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    containers = lib.mkMerge (builtins.map makeContainer cfg.runners);
  };
}
