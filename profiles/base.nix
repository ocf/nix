{ config, pkgs, ... }:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Timezones and Locale
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # TODO: If this user is accessed, send audit notification to staff via a forcecommand.
  # A user to use iff we can no longer access nodes via teleport.
  users.users.ocfemergency = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # This should contain the public keys of 1) the current Site Managers 2) a USB TPM locked in a box in the
    # server room. We haven't gotten to setting up the second thing yet, but do this eventually(TM).
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiiq/rSfG+bKmqKZfCSl1z2r7rc3Wt/Paya/JYmjdSO strudel@nikhiljha.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2yyisYL1t5u4f0FPBFKs0jAr4MWZphCb8beBvu7xSw etw+a@ocf.berkeley.edu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHC9Yh1qdHa9rq28Ki0i53vtHgg9ksKq8vg9M+9GGPA5 etw+d@ocf.berkeley.edu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPeJeRNwcPaZupbmCEtUIOuLDfhow35byMp548TUDYP rjz+u@ocf.berkeley.edu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlViRB5HH1bTaS1S7TcqVBSuxKdrbdhL2CmhDqc/t6A oliverni@ocf.berkeley.edu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILIM4dbtLQlsXn0d7GlrwLvipOLakJgQ58MdracqGfPa kian@ocf.berkeley.edu"
    ];
  };

  # Make ocfemergency effectively root via sudo rules.
  security.sudo.extraRules = [
    {
      users = [ "ocfemergency" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Base set of packages to install...
  environment.systemPackages = with pkgs; [
    # System Utilities
    util-linux
    iproute2
    ethtool

    # Helpful Tools
    vim
    wget
    git
  ];

  # This can run concurrently with Teleport SSH. We use this just in case!
  services.openssh.enable = true;

  # OCF Kerberos + LDAP
  ocf.auth.enable = true;

  # Teleport
  services.teleport = {
    enable = true;
    settings = {
      version = "v2";
      teleport = {
        nodename = config.networking.hostName;
        # This file needs to be manually placed.
        # Maybe it can be automated once ~njha builds the cool TPM-based trust thing.
        # Then as long as hardware has ever been provisioned in the past, it can grab its own token.
        auth_token = "/var/lib/ocfteleport/authtoken";
        auth_servers = [ "tele.ocf.io:443" ];
      };
      ssh_service.enabled = true;
      auth_service.enabled = false;
      proxy_service.enabled = false;
      app_service.enabled = false;
      kubernetes_service.enabled = false;
      discovery_service.enabled = false;
      db_service.enabled = false;
      windows_desktop_service.enabled = false;
    };
  };

  networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # TODO: This won't work for fallingrocks...
  networking.defaultGateway = "169.229.226.1";
  networking.defaultGateway6 = "2607:f140:8801::1";
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];
  networking.useDHCP = false;

  # THIS SETTING DOES NOT DO WHAT YOU THINK IT DOES
  # DO NOT MODIFY IT UNTIL YOU HAVE READ AND UNDERSTOOD
  # https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
