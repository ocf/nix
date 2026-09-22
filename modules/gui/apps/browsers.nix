{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.gui.apps;
in
{
  options.ocf.gui.apps.browsers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Enable browser configuration";
      default = cfg.enable;
    };

    handlePDFs = lib.mkOption {
      type = lib.types.bool;
      description = "Use browser as PDF viewer";
      default = true;
    };
  };

  config = lib.mkIf cfg.browsers.enable {
    environment.systemPackages = with pkgs; [
      firefox
      librewolf
      tor-browser
      mullvad-browser
      google-chrome # absolutely proprietary
      ungoogled-chromium
    ];

    # FIXME: cosmic files does not read the multiple mimeapps.list files
    # correctly, but it does correctly read the one in XDG_CONFIG_HOME. thus,
    # mimeapps.list is stored in skel until this is fixed.
    /*
      xdg.mime.defaultApplications = {
        "application/pdf" = lib.mkIf cfg.apps.browsers.handlePDFs "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    */

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

        # not needed since home directories are on tmpfs
        #SanitizeOnShutdown = {
        #  Cache = true;
        #  Cookies = true;
        #  Downloads = true;
        #  FormData = true;
        #  History = true;
        #  Sessions = true;
        #  SiteSettings = true;
        #  OfflineApps = true;
        #};

        DontCheckDefaultBrowser = true;
        DisableBuiltinPDFViewer = true;
        OverrideFirstRunPage = "https://www.ocf.berkeley.edu/about/lab/open-source";

        Authentication.SPNEGO = [
          "auth.ocf.berkeley.edu"
          "idm.ocf.berkeley.edu"
        ];

        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };
        };

        Bookmarks = [
          {
            Title = "bCourses";
            URL = "https://bcourses.berkeley.edu/";
            Favicon = "data:image/png;base64,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";
          }
          {
            Title = "bDrive";
            URL = "http://bdrive.berkeley.edu/";
            Favicon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAMAAABEpIrGAAAAyVBMVEUAAAAAr1AAr1YAr1cAr1YAr1cAr1gAsVYAr1cAr1YAr1gAr1oAsFcAr1cAr1hAt0T+xwD/zwAAsVb9xQD+yAD9xwD/xwAdl7cKp3gAr1gztEf+xwAyh/8yiP//xwD8xwAxh/8wh///xQAyh/8xh/8wh/8yhv//xwD/xwAyh/8xhv8wgP/9xgAyhf//yQD9yAAwhf8xhv/9yAAAr1cgskzOwxH+xwBguDbexAt/uywZmqsxhv/Lt0BLjt+kqnA+iu/xwxCKoo/YuzCbP8MIAAAAM3RSTlMAEH/fz48gX+9QnzCvv2BA3xB/gO+fQN+fgJ+/YK+fYN9AMH+/IHBgIJ/vEJCAf5+AoJCo8MHqAAABCElEQVQ4y62T2VbCQBBECyMIrkQj7iiaaAT31lLT7v//UT5Mth6SN+ptcu/pmZo5ARaazlIgstzttfGVvoiISDBo5gMp02j0gkrodxqEVaml2zBATNbmhHUrbPh8U7xseULg8edhaPi2P+CFO20VRUTklYzCtooiIm8kd1sriryTJEelsJdlWZZl+wd5DkmSPCr4sbqcFB/GTuBpvj7LBZ249XnOmVe9KLjGThgWgquaaJVLALgqOaMUwHVNmM6AtBpA3tRPoKp6C9zVOCNgpiZJSpPQHEFV47EVUmBqjQ96WyC2wqcR7gFMrKBf3g7AgxW+f2gvas749TmQPJrL+HMP8TRazA/9D23Ld0kpSWhtAAAAAElFTkSuQmCC";
          }
          {
            Title = "bMail";
            URL = "http://bmail.berkeley.edu/";
            Favicon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEjUlEQVRYw+WXXYhVVRTHf2ufc+91vscxyxQHH6IMLZMyQpgLM5FRL71okAYGg0EQCimSYhF9afbSF00lkhJkSRBWBD3UlPowKJkvRYJJIOYwNjrjzP08e+/Vwz1X752ZO+PoQEEL1uXCXmf911lf/33g/y6i3ftABLwFlyuphKgdxRx4YUZA/MEWpKWARgYaIqj3SH0CnGIAuHc5IHOB+UiQ0OJF7GM78Ku33Dh4zzxkzTA6UA+hJoD5wBwW3AL1KUS797UBz6J+NS5Tp9FIHy67C5f7VaNRwBMc2nNd4O6VRUig0JqHRruEpuI2WvIP0KSjUp/8jFnJnhB4HXgaQUqP6W14uwxf3ATai83gHn2c4NuD0wK3GxfDsMe3FpB82CUp/zbK0isGxizF660hsBbK4GXRu9TbT/D5rdjMAdSqe+hh1GcJvz8yKXC0+j5kloMRhwYqkvRPkPC78SwYYxoATxnUN9XwtQDv3gfZjC+k1BURD7azo3bKH1mJWAP5ALKJFEa3YKUHHQcOKJag2Wi+vzQFE0sL6l5TdW+gxVYtA3Wmx6e8K406gXwIxWA2yi6cvIrSXMv5b+5mjF48huYHxlfhaqRJVDeC+QhoBxAEV5EJ15XGiAEnEJl2nHyIyiYgOeHso5yyc9mbW06ohb/RgZ8wc1YgybYJzeOfNcA8YKPHn0QE25UGVVRB1QFyD8I7qHTUXjzQ5xfSk1vJWW3FgEA0hL9wFB39A9BxtaqQDuBTYBXeg+pVr7AqPuugxmt4hEPmDl52aX63zeSdjRcRAi6Hv3QSHTkN6ioKMq40dwL7EVkvICIiKOuBffHZhOBZE7Knbgk7wxWcdSnyzpFxSlhlpg4dPQN2pEjypghoGJ8RiEvxrsLCOAtbgVrTRM4EmV1ttyc+r29PWm8Q/NV1MNF4aH6gHzuyFfRU7eakCXgp1prgRjndV9+2bU9re/9lD1nnyVSoqdX6mvnzK9StU3zfJHsniLUGEchxCrL2wbvv/zLnjOacIeelSk1tngwCjYZ/xtt1oIemTQTKN1izdv/8RccbsnXG2mZK2lKl4eQLPQNB6gzqu4G/gA0wxTPg8PIxzmwnMhc2LEsTOq1Zx3BqSisADAKbgXPA80BjDessyptEZjehyeISSDQbN4n7KQNQVaS0qnOI7ET1HLAznoRKuQDsQNkLOPIhUqc42zZmp0jV/ykDSPx4tFSNzg5Q9fG8nwfeAhbHZqeB5xD5GhS8EPaWWNM8WeNWJddagnKqeo9UMuF3MY1vBxLxneJYeTOWwQFStrkKU6fdA2OCcJ1pUEHF/wKsi/0Wym2W+KH6vtAYNU3uc7rTFfQeJupME6B4pBi3PUaFRO/RcfaNUVN12a+3BFV90Xv4mm0b7AxnYLrSEP3LAQQ2MWUAQ0DrWA6ZqQCsq+1TYCgEXgSeqQjCACeA4Rn5Kiox77AqJ+IrWpmLL4nwQShe3lOjX4yh1EFgSCS44QBmp+BSjiGvdANzKo5GLo/QH6pRjTfb+ar0iODV3nAAg3lwRTBJBuMXuzKFLc3/ga/jfwC17wLDKhvcqgAAAABJRU5ErkJggg==";
          }
          {
            Title = "Gradescope";
            URL = "https://www.gradescope.com/auth/saml/berkeley/";
            Favicon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAMAAABEpIrGAAACQ1BMVEUAAAA+lvc/lvdAmfdAmPg6mfRNmf9Mmv9DvP9Vqv9Wq/8whf9Mjvs9j/Y6kvY6k/c6k/ZAmPY7mfUAgP8AeP8A//87mPVFl/ZFmPZEl/dEmPdEmfdFmfdDifY9lPdGov9Gpf9GnPdDi/lAm/pCoPw9lPY5lvg5wPI8lPg9lvg8kvc6kvgkfP5Bm/hCm/g/l/c+lfc6l/U9k/Y2j/I8k/dErPM/lfJAlfY/lfc+lPc+lfY/lfg9lfc6kvQ9lPhApfQ/lfQ9lvU/lvc/lvc/lvdAmfdAmPg/lvc/lvdAmPg/lvc/lvdAmfdAmPg8l/g+lfg+lvg+l/g9lfc/lfc/l/dAmPdAmPdAmPc/mPc/lvc/lvdAmPc+lvdAmPc9lfc9lPg9lPg9lfg9lfg9lfc/mfc+lfdAmPdAmPdAmPdAmPdAmfdBm/g9lfg/lfdAmfdCnPg+lPhAmPdCnPhAmPk9lfdAmPdAlvc9lPg/l/g+lvdBm/dCnPg+lvg/mPhCm/dCnPg9lfc/mPdCm/dCnPg+lfg/l/c+lfc/lvdAmPc/l/dAmfc/l/c/l/dCnPc+lvc/l/dAmfdAmPg/l/dAl/dAmPc/l/c9l/c+lvc+lvc+lvc+lvc/l/dAl/c/lvc/lvc/l/c/l/c/l/c/mPc+lfY+lfg+lvc+lvg+l/c/lvc/l/c/lvc/lvdBjvQ+lPc+lPc+k/c9kvc9k/VAlfk8k/g9lPc9lfc8kvY9k/g9k/c6kPdAlPY8jfg/lvdAmfc/l/dAl/dAmPc1VvCeAAAAvHRSTlMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAse4B+NVv7bVn3/GsCJzs6Nwqd5+Pk2Aux8bDwBjtGRUc0BBXD6+no7KwNF9W6DtS5CiREFzCZ2uNDOcvyRxiy8UZc74mP78XgVJDzWvj9bLHzx1cGXqqoqaQwDoGbmZxzCDujRwdtilofAQYLCwsDAQYHBwUECwUGAl7Ij+UAAAABb3JOVAHPoneaAAABkElEQVQ4y2NgIBUwMjExMTExs7Cy4VLg5Ozi4uLqhluBu8eePXv2euJW4OW9Z88eH19Wdg5OTk4ubtwKeHj5+PkFBHEr8PMPCAwMDMKpQCg4JDQsLDwCJi4sLCwsLCwiLApTIBYZtW/Pnv3RMAXiEpKSUlLSMrIIBTF79uzZEwtTIBcXn5CYmJScgqpgH1wBU2paekZmVnYOTgW5efv37DmQX8CEU0Hhvj179heRp0BeQVEJjwJlFRZVNXXcCjQ0tYpLSstwK9DWKa+orKrWxamApaZ23566ej2cChoaD+zZ09SMW0FL6x78Ctr2EFDQTmMFezoImdCJU4FQZMyePfu7uhl69u3bt6+3Xi8378CB/XvzC5j6+vft2zdholjkpAOTp0ydxjB9xsyZs2bP0Z87b/6CBQsXLTZYsnTWzJkzlxkuX7Fy1eo1jAxr161fv37DRqNNm7ds3bp1m7HJ9h071q/bsdPUbNduJiZzCwYDA0tLS0srA2sbRkZGRitbOTsDA0sDOS17BwtLRysGBgDpSmxGlRbFCAAAAABJRU5ErkJggg==";
          }
        ];

        HttpAllowlist = [
          "http://bdrive.berkeley.edu/"
          "http://bmail.berkeley.edu/"
        ];

        Preferences = {
          # OCF (HP B&W): default to double-sided, black & white, letter
          "print.printer_OCF-BW.print_duplex" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_OCF-BW.print_in_color" = {
            Value = false;
            Status = "default";
          };
          "print.printer_OCF-BW.print_paper_height" = {
            Value = "279.4";
            Status = "default";
          };
          "print.printer_OCF-BW.print_paper_id" = {
            Value = "na_letter";
            Status = "default";
          };
          "print.printer_OCF-BW.print_paper_size_unit" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_OCF-BW.print_paper_width" = {
            Value = "215.9";
            Status = "default";
          };
          # OCF-Color (Epson): letter paper size
          "print.printer_OCF-Color.print_paper_height" = {
            Value = "279.4";
            Status = "default";
          };
          "print.printer_OCF-Color.print_paper_id" = {
            Value = "na_letter";
            Status = "default";
          };
          "print.printer_OCF-Color.print_paper_size_unit" = {
            Value = 1;
            Status = "default";
            Type = "number";
          };
          "print.printer_OCF-Color.print_paper_width" = {
            Value = "215.9";
            Status = "default";
          };
          "widget.wayland.fractional-scale.enabled" = {
            Value = false;
            Status = "default";
          };
          "toolkit.legacyUserProfileCustomizations.stylesheets" = {
            Value = true;
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
