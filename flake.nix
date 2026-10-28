{
  description = "MLFPGA_engine top-level flow environment: LibreLane pinned as in versions.env";

  # Binary cache: add https://nix-cache.fossi-foundation.org to the machine's nix.conf
  # (substituters + trusted-public-keys), otherwise the EDA tools are built from source.

  inputs = {
    # Must recommend PDK_HASH in versions.env (checked by `make check-versions`).
    librelane.url = "github:librelane/librelane/dcea37e640e792186684004142e51a81a0a554de";
  };

  outputs =
    { librelane, ... }:
    let
      nix-eda = librelane.inputs.nix-eda;
    in
    {
      devShells = nix-eda.forAllSystems (
        system:
        let
          pkgs = librelane.legacyPackages.${system};
        in
        {
          # LibreLane's own shell, plus the repo root on PYTHONPATH so LibreLane finds
          # librelane_plugin_regions when called directly (the Makefile sets it too).
          default = pkgs.librelane-shell.override {
            extra-env = [
              {
                name = "PYTHONPATH";
                eval = "$PRJ_ROOT\${PYTHONPATH:+:$PYTHONPATH}";
              }
            ];
          };
        }
      );
    };
}
