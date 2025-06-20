{ lib, ... }:

{
  options.ocf.github-actions = {
    enable = lib.mkEnableOption "Enable Containerized OCF GitHub Actions Runners";
    runners = lib.mkOption {
      type = lib.types.listOf lib.mkOption {

        enable = lib.mkEnableOption "Enable this self-hosted runner";

        owner = lib.mkOption {
          type = lib.types.string;
          description = "Owner of the GitHub Repository";
          default = "ocf";
        };

        repo = lib.mkOption {
          type = lib.types.string;
          description = "Name of the GitHub Repository";
        };

        workflow = lib.mkOption {
          type = lib.types.string;
          description = "Name of the GitHub Actions Workflow";
        };

        tokenPath = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to GitHub fine grained PAT with the following permissions:
              Organization:
                - Read and Write access to organization self hosted runners
              Repository:
                - Read access to metadata
                - Read and Write access to administration
          '';
        };

        instances = lib.mkOption {
          type = lib.types.int;
          description = "Number of parallel instances for this workflow";
          default = 1;
        };

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          description = "Packages to be installed in the runner enviornment";
          default = [ ];
        };

      };
      default = [ ];
    };
  };

}
