{ lib, config, ... }:

let
  cfg = config.ocf.github-actions;
  template =
    { enable, owner, repo, workflow, tokenPath, packages, instances, ... }:

    if enable
    then
      {
        "ci-${owner}-${repo}-${workflow}" = {
          ephemeral = true;
          autoStart = true;
          privateUsers = "pick";
          bindMounts = {
            "github-token" = {
              hostPath = tokenPath;
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
                      let
                        name = "ci-${owner}-${repo}-${workflow}-${toString (i+1)}";
                      in
                      {
                        name = name;
                        value = {
                          enable = true;
                          ephemeral = true;
                          user = null;
                          group = null;
                          replace = true;
                          noDefaultLabels = true;
                          extraLabels = [ "ci-${owner}-${repo}-${workflow}" ];
                          url = "https://github.com/${owner}/${repo}";
                          tokenFile = "/run/token";
                          extraPackages = packages;
                        };
                      }
                    )
                    instances
                );
              system.stateVersion = "24.11";
            };
        };
      }
    else { };


in
{

  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    containers = lib.mergeAttrsList (builtins.map (runner: (template (with runner; { inherit enable owner repo workflow tokenPath packages instances; }))) cfg.runners);
  };
}
