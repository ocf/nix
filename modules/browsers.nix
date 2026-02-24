{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.browsers;
in
{
  options.ocf.browsers = {
    enable = lib.mkEnableOption "Enable desktop environment configuration";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      google-chrome
      firefox
    ];

    programs.firefox = {
      enable = true;
      policies = {
        Homepage.URL = "https://www.ocf.berkeley.edu/about/lab/open-source";
        PromptForDownloadLocation = true;

        FirefoxHome = {
          TopSites = false;
          SponsoredTopSites = false;
          Highlights = false;
          Pocket = false;
          SponsoredPocket = false;
          Snippets = false;
          Locked = true;
        };

        DisableTelemetry = true;
        DisableFirefoxAccounts = true;
        DisableFormHistory = true;
        OfferToSaveLoginsDefault = false;
        HttpsOnlyMode = "enabled";

        SanitizeOnShutdown = {
          Cache = true;
          Cookies = true;
          Downloads = true;
          FormData = true;
          History = true;
          Sessions = true;
          SiteSettings = true;
          OfflineApps = true;
        };

        DontCheckDefaultBrowser = true;
        DisableBuiltinPDFViewer = true;
        OverrideFirstRunPage = "https://www.ocf.berkeley.edu/about/lab/open-source";

        Authentication.SPNEGO = [ "auth.ocf.berkeley.edu" "idm.ocf.berkeley.edu" ];

        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };
        };

        Preferences = {
          "print.printer_color-single.print_paper_height" = {
            Value = "279.4";
            Status = "default";
          };
          "print.printer_color-single.print_paper_id" = {
            Value = "na_letter";
            Status = "default";
          };
          "print.printer_color-single.print_paper_size_unit" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_color-single.print_paper_width" = {
            Value = "215.9";
            Status = "default";
          };
          "print.printer_double.print_in_color" = {
            Value = false;
            Status = "default";
          };
          "print.printer_double.print_paper_height" = {
            Value = "279.4";
            Status = "default";
          };
          "print.printer_double.print_paper_id" = {
            Value = "na_letter";
            Status = "default";
          };
          "print.printer_double.print_paper_size_unit" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_double.print_paper_width" = {
            Value = "215.9";
            Status = "default";
          };
          "print.printer_single.print_in_color" = {
            Value = false;
            Status = "default";
          };
          "print.printer_single.print_paper_height" = {
            Value = "279.4";
            Status = "default";
          };
          "print.printer_single.print_paper_id" = {
            Value = "na_letter";
            Status = "default";
          };
          "print.printer_single.print_paper_size_unit" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_single.print_paper_width" = {
            Value = "215.9";
            Status = "default";
          };
        };
      };
    };

    # Force Chrome to use Wayland, rather than XWayland
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    programs.chromium = {
      enable = true;

      extensions = [
        "ddkjiahejlhfcafbddmgiahcphecmpfh" # ublock origin lite
      ];

      extraOpts = {
        # https://chromeenterprise.google/policies/

        # Set OCF homepage
        HomepageLocation = "https://www.ocf.berkeley.edu/about/lab/open-source";
        HomepageIsNewTabPage = false;
        ShowHomeButton = true;
        RestoreOnStartup = 4;
        RestoreOnStartupURLs = [
          "https://www.ocf.berkeley.edu/about/lab/open-source"
        ];

        # Do not store browser history etc.
        ForceEphemeralProfiles = true;
        SavingBrowserHistoryDisabled = true;
        PasswordManagerEnabled = false;
        IncognitoModeAvailability = 0;

        # Avoid reporting data to and integrating with Google
        BrowserSignin = 0;
        MetricsReportingEnabled = false;
        CloudPrintProxyEnabled = false;
        CloudPrintSubmitEnabled = false;
        HideWebStoreIcon = true;
        SyncDisabled = true;
        TranslateEnabled = true;
        DefaultBrowserSettingEnabled = false;

        # Allow SPNEGO for Keycloak SSO
        AuthServerAllowlist = "auth.ocf.berkeley.edu,idm.ocf.berkeley.edu";
        AuthNegotiateDelegateAllowlist = "auth.ocf.berkeley.edu,idm.ocf.berkeley.edu";

        # Printing from Chrome's PDF viewer often results in cut-off pages
        DisablePrintPreview = true;
        AlwaysOpenPdfExternally = true;

        # Disable Privacy Sandbox popup
        PrivacySandboxAdMeasurementEnabled = false;
        PrivacySandboxPromptEnabled = false;
        PrivacySandboxAdTopicsEnabled = false;
        PrivacySandboxSiteEnabledAdsEnabled = false;

      };
    };
  };
}
