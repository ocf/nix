{ pkgs, lib, inputs, config, ... }:

{
  nix = {
    channel.enable = false;
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    settings = {
      experimental-features = "nix-command flakes";
      nix-path = lib.mapAttrsToList (name: _: "${name}=flake:${name}") inputs;
    };
    gc = {
      automatic = true;
      dates = "weekly";
    };
  };

  ocf = {
    auth.enable = lib.mkDefault true;
    shell.enable = lib.mkDefault true;
  };

  age.rekey = {
    masterIdentities = lib.filesystem.listFilesRecursive ../secrets/master-identities;
    storageMode = "local";
    localStorageDir = inputs.self + "/secrets/rekeyed/${config.networking.hostName}";
    hostPubkey = builtins.readFile (inputs.self + "/secrets/host-keys/${config.networking.hostName}.pub");
  };

  boot.loader = {
    systemd-boot = {
      enable = lib.mkDefault true;
      consoleMode = "max";
    };

    grub.enable = lib.mkDefault false;
    efi.canTouchEfiVariables = true;
  };

  security.pam = {
    services.login.makeHomeDir = true;
    services.sshd.makeHomeDir = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Temporary, make dedicated deploy user later
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlViRB5HH1bTaS1S7TcqVBSuxKdrbdhL2CmhDqc/t6A" # oliverni
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiiq/rSfG+bKmqKZfCSl1z2r7rc3Wt/Paya/JYmjdSO" # njha
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHC9Yh1qdHa9rq28Ki0i53vtHgg9ksKq8vg9M+9GGPA5" # etw
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOssvEhZ5BG96yH4fsjYhY6xKt3AKyuyAD5TXapdQUw" # lemurseven
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOaJJvOUG08qr3yeeQRB71M30cdPMuO69nsf0CodALa" # jaysa
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPeJeRNwcPaZupbmCEtUIOuLDfhow35byMp548TUDYP" # rjz
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6zftyMUeIQVYkRag6CxWqYShjWnErQ24NeaU95Bp2z" # laksith
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDJ12A/hT19X7al32GiCWa4OYIp5kC+pC0YeeccIi+BQ" # ronitnath
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdAe7sPMxaidnqOah3UVrjt41KFHHOYleS1VWGH+ZUc" # storce
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/4nHyz4zaL2g7o7oLQqdLnz02JFniBOXjZ6gSrtUlO" # sbwilliams
  ];

  programs.ssh = {
    package = pkgs.openssh_gssapi;
    extraConfig = ''
      CanonicalizeHostname yes
      CanonicalDomains ocf.berkeley.edu
      Host *.ocf.berkeley.edu *.ocf.io 169.229.226.* 2607:f140:8801::*
          GSSAPIAuthentication yes
          GSSAPIKeyExchange yes
          GSSAPIDelegateCredentials no
    '';
  };

  environment.systemPackages = with pkgs; [
    # System utilities
    dnsutils
    # This doesn't work on aarch64 for some reason
    # cpufrequtils
    pulseaudio
    pciutils
    usbutils
    cups
    ipmitool
    smartmontools
    nvme-cli

    # Networking tools
    rsync
    wget
    curl

    # Other useful stuff
    tmux
    htop
    file
    vim
    git
    killall

    comma-with-db
  ];

  services = {
    openssh = {
      enable = true;
      settings.X11Forwarding = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };

    envfs = {
      enable = true;

      # We need /bin/bash etc. to work because people's shells are set to it
      extraFallbackPathCommands = ''
        ln -s ${lib.getExe pkgs.bash} $out/bash
        ln -s ${lib.getExe pkgs.zsh} $out/zsh
        ln -s ${lib.getExe pkgs.fish} $out/fish
        ln -s ${lib.getExe pkgs.xonsh} $out/xonsh
      '';
    };

    fwupd.enable = true;
    avahi.enable = true;
  };

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  networking.firewall.enable = false;

  environment.etc = {
    papersize.text = "letter";
    "cups/lpoptions".text = "Default double";
    "cups/client.conf".text = ''
      ServerName printhost.ocf.berkeley.edu
      Encryption Always
    '';
  };

  environment.etc."nixos/configuration.nix".text = ''
    {}: builtins.abort "This machine is not managed by /etc/nixos. Please use colmena instead."
  '';

  systemd.services.nix-remove-profiles = {
    description = "Remove old NixOS generations but leave store cleanup to nix.gc";
    script = ''
      keepGenerations=5
      profile="/nix/var/nix/profiles/system"

      to_delete=$(nix-env --list-generations --profile "$profile" | awk '{print $1}' | head -n -$keepGenerations)

      if [ -n "$to_delete" ]; then
        to_delete=$(echo "$to_delete" | tr '\n' ' ')
        nix-env --delete-generations $to_delete --profile "$profile"
      fi
    '';
    serviceConfig = {
      Environment = "PATH=/run/current-system/sw/bin";
      Type = "oneshot";
    };
  };

  systemd.timers.nix-remove-profiles = {
    description = "Run NixOS profile cleanup periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly"; # Runs once a week
      Persistent = true;
    };
  };
}
