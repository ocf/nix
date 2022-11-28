{ config, pkgs, lib, ... }:

let
  kubePkgs = with pkgs; [ kubernetes cri-o util-linux iproute2 ethtool iptables socat conntrack-tools ];
in {
  # Configuration for Nodes
  options.services.ocfKubernetes = {
    enable = lib.mkEnableOption "Enables everything needed to run kubeadm.";
    isLeader = lib.mkOption {
      default = false;
      example = true;
      description = "Currently identical to worker, but enables kube-vip as a static pod.";
      type = lib.types.bool;
    };
  };

  config = lib.mkIf config.services.ocfKubernetes.enable {
    environment.etc = {
      "kubernetes/manifests/kubevip.yaml".source = lib.mkIf config.services.ocfKubernetes.isLeader ./kubevip.yaml;
      "kubernetes/kubeadm.yaml".source = ./kubeadm.yaml;
    };

    boot.kernelModules = [
      "aes"
      "algif_hash"
      "br_netfilter"
      "cls_bpf"
      "cls_ingress"
      "cryptd"
      "encrypted_keys"
      "ip6_tables"
      "ip6table_filter"
      "ip6table_mangle"
      "ip6table_raw"
      "ip_set"
      "ip_set_hash_ip"
      "rbd"
      "sch_fq"
      "sha1"
      "sha256"
      "xt_CT"
      "xt_TPROXY"
      "xt_mark"
      "xt_set"
      "xt_socket"
      "xts"
    ];

    # <https://docs.cilium.io/en/stable/operations/system_requirements/#mounted-ebpf-filesystem>
    fileSystems."/sys/fs/bpf" = {
      device = "bpffs";
      fsType = "bpf";
    };

    # <https://kubernetes.io/docs/reference/ports-and-protocols/>
    networking.firewall.allowedTCPPorts = [ 6443 2379 2380 10250 10259 10257 10250 ];
    networking.firewall.allowedTCPPortRanges = [ { from = 30000; to = 32767; } ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;  
      "net.ipv6.conf.all.forwarding" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
    };

    environment.systemPackages = kubePkgs;

    virtualisation.cri-o.enable = true;
    virtualisation.cri-o.extraPackages = [ pkgs.gvisor ];

    systemd.services.kubelet = {
      description = "Kubelet <https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/>";
      wantedBy = [ "multi-user.target" ];

      path = kubePkgs;

      serviceConfig = {
        StateDirectory = "kubelet";
        ConfiguratonDirectory = "kubernetes";

        # KUBELET_KUBEADM_ARGS - generated by kubeadm
        EnvironmentFile = "-/var/lib/kubelet/kubeadm-flags.env";

        Restart = "always";
        StartLimitIntervalSec = 0;
        RestartSec = 10;

        ExecStart = ''
          ${pkgs.kubernetes}/bin/kubelet \
            --kubeconfig=/etc/kubernetes/kubelet.conf \
            --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
            --config=/var/lib/kubelet/config.yaml \
            $KUBELET_KUBEADM_ARGS
        '';
      };
    };
  };
}