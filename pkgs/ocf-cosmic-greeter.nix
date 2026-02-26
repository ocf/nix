{ cosmic-greeter }:

cosmic-greeter.overrideAttrs {
  patches = [ ./ocf-cosmic-greeter/add-logout-button.patch ];
}

