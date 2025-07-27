{ lib, ... }:

{
  options.ocf.github-actions = {
    enable = lib.mkEnableOption "Enable Containerized OCF GitHub Actions Runners";
    runners = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {

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
            type = lib.types.str;
            description = "Name of the GitHub Actions Workflow";
          };

          tokenPath = lib.mkOption {
            type = lib.types.path;
            description = ''
              Path to GitHub fine grained Personal Access Token with the following permissions:
                Repository:
                  - Read access to metadata
                  - Read and Write access to administration
                Organization:
                  - Read and Write access to organization self hosted runners
            '';
          };

          packages = lib.mkOption {
            type = with lib.types; listOf package;
            description = "Packages to be installed in the runner enviornment";
            default = [ ];
          };

          instances = lib.mkOption {
            type = lib.types.int;
            description = "Number of parallel instances for this workflow";
            default = 1;
          };

        };
      }
      );
    };
  };

}
