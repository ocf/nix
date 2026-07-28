{
  inputs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.github-actions;

  getSecrets =
    runner-cfg:
    lib.mkIf runner-cfg.enable {
      ${runner-cfg.token}.rekeyFile =
        inputs.self + "/secrets/master-keyed/github/ci-tokens/${runner-cfg.token}.age";
    };

  makeContainer =
    runner-cfg:
    let
      name =
        if (builtins.isNull runner-cfg.workflow) then
          "ci-${runner-cfg.owner}-${runner-cfg.repo}"
        else
          "ci-${runner-cfg.owner}-${runner-cfg.repo}-${runner-cfg.workflow}";
    in
    lib.mkIf runner-cfg.enable {
      ${name} = {
        ephemeral = true;
        autoStart = true;

        bindMounts = {
          "github-token" = {
            hostPath = config.age.secrets.${runner-cfg.token}.path;
            mountPoint = "/run/token";
            isReadOnly = true;
          };
        };
        config =
          { ... }:
          {
            nix.settings.experimental-features = "nix-command flakes";
            networking.firewall.enable = true;

            services.github-runners = builtins.listToAttrs (
              builtins.genList (i: {
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
              }) runner-cfg.instances
            );

            systemd.services = lib.mapAttrs' (runnerName: runnerCfg: {
              # systemd service is prefixed with "github-runner-"
              name = "github-runner-${runnerName}";

              # dont interrupt a running job on a nixos configuration switch.
              # if github-runners.*.ephemeral = true, the runner will exit on
              # job completion, and systemd will start the updated github
              # runner.
              #
              # NOTE: this means that the runner will only update after the
              # next job, even if no job was running during the switch
              value = {
                restartIfChanged = false;
              };
            }) config.services.github-runners;

            system.stateVersion = "24.11";
          };
      };
    };

in
{
  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    age.secrets = lib.mkMerge (builtins.map getSecrets cfg.runners);
    containers = lib.mkMerge (builtins.map makeContainer cfg.runners);

    # dont fail/interrupt jobs on a nixos configuration switch by restarting
    # the container. instead, live reload the containers, which runs
    # switch-to-configuration within the container.
    systemd.services = lib.mapAttrs' (containerName: containerCfg: {
      name = "container@${containerName}";
      value = {
        reloadIfChanged = true;
      };
    }) config.containers;
  };
}
