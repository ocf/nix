{ cosmic-greeter, rustPlatform }:

cosmic-greeter.overrideAttrs (oldAttrs: {
  patches = [ ./ocf-cosmic-greeter/add-logout-button.patch ];
})
