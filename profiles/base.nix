{
  self,
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

let
  secretsDir = inputs.self + "/secrets";
  hostKeyFile = secretsDir + "/host-keys/${config.networking.hostName}.pub";
  variant_id =
    if config.system.nixos.variant_id != null then config.system.nixos.variant_id else "ocf";
  gitRev =
    if (self ? shortRev) then
      self.shortRev
    else if (self ? dirtyShortRev) then
      self.dirtyShortRev
    else
      "nullrev";
in
{
  system.configurationRevision = gitRev;
  # we do not include self.lastModifiedDate since:
  # - the bootloader menu already includes "built on"
  # - date can be checked from the revision hash with an extra step
  # - label is much shorter without the date
  system.nixos.label = "${variant_id}.${gitRev}.${config.system.nixos.version}";

  nix = {
    channel.enable = false;
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    settings = {
      experimental-features = "nix-command flakes";
      nix-path = lib.mapAttrsToList (name: _: "${name}=flake:${name}") inputs;
      builders-use-substitutes = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
    };
    settings = {
      # makes devenv shells build significantly faster
      trusted-substituters = [
        "https://devenv.cachix.org"
        "https://cache.ocf.berkeley.edu"
      ];
      trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "cache.ocf.berkeley.edu-1:6n9lihkjExzagz8GYR1QY/ZthT/XAKOy+ju5Jxd6wBg="
      ];
    };
    extraOptions = ''
      extra-substituters = https://devenv.cachix.org https://cache.ocf.berkeley.edu
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.ocf.berkeley.edu-1:6n9lihkjExzagz8GYR1QY/ZthT/XAKOy+ju5Jxd6wBg=
    '';
  };

  nixpkgs.flake.setNixPath = true;

  ocf = {
    auth.enable = lib.mkDefault true;
    managed-deployment.enable = lib.mkDefault true;
    acme.enable = lib.mkDefault true;
    cli.enable = lib.mkDefault true;
    motd.enable = lib.mkDefault true;
    etc.enable = true;

    # the case against globally nfs mounted /home:
    # - you can scp between hosts
    # - global /home (and global user config as a result) introduces a huge
    #   dependency on the nfs server for being able to login anywhere (logins
    #   would hang if nfs was down).
    # - global /home means that we are trusting every host (and every program
    #   running as any user on any host) not to write malicious files/config
    #   on the shared home directory which then instantly propagates to every
    #   other host at the ocf (catastrophic).
    #
    # this is a middle ground that provides convenient access to the global
    # home directories:
    # - nfs server is configured with root_squash and only allows acting as a
    #   user other than nobody if a valid kerberos ticket is available.
    # - similar to the desktops, global homes are mounted at /remote and
    #   /services by default on every host.
    # - unlike desktops, these global homes are not looked at for
    #   configuration or a bind mount at ~/remote.
    # - nfs client should not expect a ticket to be available, as the user may
    #   not have logged with GSSAPI authenticated ssh; thus the nfs client
    #   should not touch /remote or /services at all without the user manually
    #   doing so with a ticket.
    # - softerr is used to prevent infinite hangs on IO operations to /remote
    #   and /services in the case that the nfs server is down.
    nfs = {
      enable = lib.mkDefault true;
      mount = lib.mkDefault true;
      kerberos = lib.mkDefault true;
      softerr = lib.mkDefault true;

      # instead of having an nfs mount for each logged in user, we mount a
      # single nfs mount at /remote and if ocf.home.mountRemote is true, bind
      # mount ~/remote -> /remote/w/wa/waddles (for username waddles)
      asRemote = lib.mkDefault true;
    };
  };

  age.rekey = {
    masterIdentities = lib.filesystem.listFilesRecursive (secretsDir + "/master-identities");
    storageMode = "local";
    localStorageDir = inputs.self + "/secrets/rekeyed/${config.networking.hostName}";
    hostPubkey = lib.mkIf (builtins.pathExists hostKeyFile) (builtins.readFile hostKeyFile);
  };

  # Mitigate Dirty Frag (universal Linux LPE via esp4/esp6/rxrpc page-cache write)
  # https://github.com/V4bel/dirtyfrag
  boot.extraModprobeConfig = ''
    install esp4 /bin/false
    install esp6 /bin/false
    install rxrpc /bin/false
  '';

  boot.tmp.useTmpfs = true;

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

  environment.variables.EDITOR = "${pkgs.vim}/bin/ex"; # line editor
  environment.variables.VISUAL = "${pkgs.nano}/bin/nano"; # visual editor

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
    perf
    strace
    bsd-finger # necessary for checkacct util to work

    # Networking tools
    rsync
    wget
    curl
    mtr
    traceroute
    iperf
    iperf3
    vnstat
    nethogs
    netcat-openbsd
    nmap
    iftop
    tcpdump
    whois

    # Other useful stuff
    tmux
    screen
    dtach
    reptyr
    htop
    btop
    git
    killall
    inetutils
    ldapvi
    openldap
    lsof
    jq
    pv
    pwgen
    tree
    unzip
    moreutils
    pigz
    ranger
    ncdu
    beep
    gist

    # System administration
    iotop
    parted
    powertop
    cryptsetup
    quota

    # files
    dua
    lf
    file
    micro
    ripgrep
    hexedit
    dos2unix
    bat
    lsd
    emacs

    # Default openssh doesn't include GSSAPI support, so we need to override sshfs
    # to use the openssh_gssapi package instead. This is annoying because the
    # sshfs package's openssh argument is nested in another layer of callPackage,
    # so we override callPackage instead to override openssh.
    (sshfs.override {
      callPackage =
        fn: args:
        (pkgs.callPackage fn args).override {
          openssh = pkgs.openssh_gssapi;
        };
    })

    comma-with-db

    # k8s
    teleport
    k9s
    kubectl

    # OCF utilities
    (python312.withPackages (
      ps: with ps; [
        ocflib
        dnspython
        paramiko
        requests
        tabulate
        virtualenv
      ]
    ))
    ocf-utils
    ocf-niks3-push
  ];

  programs.vim.enable = true;

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
        ln -s ${lib.getExe pkgs.tcsh} $out/tcsh
        ln -s ${lib.getExe pkgs.tcsh} $out/csh
      '';
    };

    fwupd.enable = true;
    avahi.enable = true;
  };

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  networking.firewall.enable = true;

  environment.etc = {
    papersize.text = "letter";
    "nixos/configuration.nix".text = ''
      {}: builtins.abort "This machine is not managed by /etc/nixos. Please use configs at ocf.io/gh/nix with Colmena."
    '';
  }
  // lib.optionalAttrs (!config.ocf.printhost.enable) {
    "cups/lpoptions".text = "Default OCF-BW";
    "cups/client.conf".text = ''
      ServerName printhost.ocf.berkeley.edu
      Encryption IfRequested
    '';
  };

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

  # CVE-2026-31431
  # remove after kernel is updated to a fixed release
  boot.blacklistedKernelModules = [ "algif_aead" ];
}
