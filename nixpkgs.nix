#
# This can be replaced by any method of tracking inputs.
#   - niv     https://github.com/nmattia/niv
#   - npins   https://github.com/andir/npins
#   - Flakes  https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html
#
# Using this simple purely-Nix shim serves as a placeholder.

let
  # Tracking https://github.com/NixOS/nixpkgs/tree/nixos-21.11
  rev = "062a0c5437b68f950b081bbfc8a699d57a4ee026"; # nixos-unstable
  sha256 = "sha256:6575f6d59578d34ebc7dd9a3959018fe116817effab49a6caadc2fea6d98bfd5";
  tarball = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
in
  # The builtins.trace is optional; serves as a reminder.
  builtins.trace "Using default Nixpkgs revision '${rev}'..."
  (import tarball)
