{ papers }:

papers.overrideAttrs {
  # Adds a Print button to the toolbar. (The built-in one is in a menu.)
  patches = [ ./ocf-papers/add-print-button.patch ];
}
