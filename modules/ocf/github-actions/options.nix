{ pkgs, lib, ... }:

{
  options.ocf.github-actions = {
    enable = lib.mkEnableOption "Enable Containerized OCF GitHub Actions Runners";
    runners = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ config, ... }: {

        options = {
          enable = lib.mkEnableOption "Enable this self-hosted runner";

          owner = lib.mkOption {
            type = lib.types.str;
            description = "Owner of the GitHub Repository";
            default = "ocf";
          };

          repo = lib.mkOption {
            type = lib.types.str;
            description = "Name of the GitHub Repository";
          };

          workflow = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Name of the GitHub Actions Workflow - only needed if you want to have independent runners per workflow";
            default = null;
          };

          token = lib.mkOption {
            type = lib.types.str;
            description = ''
              Name of encrypted GitHub CI Token stored in 
              `<repo-root>/secrets/master-keyed/github/ci-tokens/<token-name>.age`.

              When generating the token on GitHub ensure that it's a fine grained 
              Personal Access Token scoped to a single repo with the following 
              permissions:
                Repository:
                  - Read access to metadata
                  - Read and Write access to administration
                Organization:
                  - Read and Write access to organization self hosted runners
            '';
            default = config.repo;
          };

          packages = lib.mkOption {
            type = with lib.types; listOf package;
            description = "Packages to be installed in the runner enviornment";
            default = [ pkgs.nix ];
          };

          instances = lib.mkOption {
            type = lib.types.int;
            description = "Number of parallel instances for this workflow";
            default = 1;
          };

        };
      })
      );
    };
  };

}
