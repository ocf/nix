{ lib, ... }:

{
  options.ocf.github-actions = with lib; {
    enable = mkEnableOption "Enable Containerized OCF GitHub Actions Runners";
    runners = mkOption {
      type = with types; listOf (submodule {

        options = {
        enable = mkEnableOption "Enable this self-hosted runner";

        owner = mkOption {
          type = str;
          description = "Owner of the GitHub Repository";
          default = "ocf";
        };

        repo = mkOption {
          type = str;
          description = "Name of the GitHub Repository";
        };

        workflow = mkOption {
          type = str;
          description = "Name of the GitHub Actions Workflow";
        };

        tokenPath = mkOption {
          type = path;
          description = ''
            Path to GitHub fine grained PAT with the following permissions:
              Organization:
                - Read and Write access to organization self hosted runners
              Repository:
                - Read access to metadata
                - Read and Write access to administration
          '';
        };

        packages = mkOption {
          type = listOf package;
          description = "Packages to be installed in the runner enviornment";
          default = [ ];
        };

        instances = mkOption {
          type =int;
          description = "Number of parallel instances for this workflow";
          default = 1;
        };

      };
      }
      );
    };
  };

}
