{ hplip }:
# This patches hplip's hppsfilter.c to replace all sprintf() calls
# with snprintf() to prevent buffer overflows when CUPS passes long
# job titles to the hpps filter via argv[3].

hplip.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./ocf-hplip/hpps-snprintf.patch
  ];
})
