{ kdePackages.okular }:

kdePackages.okular.overrideAttrs {
  # toggle force rasterization by default
  patches = [ ./ocf-okular/force-rasterization.patch ];
}
