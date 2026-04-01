{ cosmic-greeter, rustPlatform }:

# Re-vendor cargo deps since upstream cargoHash is stale
# Remove cargoDeps override after `nix flake update` if build succeeds without it
# https://discourse.nixos.org/t/overriding-version-cant-find-new-cargohash/31502/10
cosmic-greeter.overrideAttrs (oldAttrs: {
  patches = [ ./ocf-cosmic-greeter/add-logout-button.patch ];
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (oldAttrs) src;
    hash = "sha256-4yRBgFrH4RBpuvChTED+ynx+PyFumoT2Z+R1gXxF4Xc=";
  };
})

