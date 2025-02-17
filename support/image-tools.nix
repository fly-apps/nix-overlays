{ lib, writeText, closureInfo, dockerTools }:

let
  inherit (lib)
    foldl
  ;
in
{
  buildSpecifiedLayers =
    { layeredContent
    # An image to start building from. Note that store path deduplication will
    # not be attempted when starting from an existing Docker image. Store deduplication
    # will happen if using a previous evaluation of buildSpecifiedLayers.
    , fromImage ? null
    }:
    (
      foldl (prev:
        # Name of the layer.
        { name ? "layer"
        # Derivations to directly include in the layer.
        # The content of the store path of these derivations (and not their
        # dependencies) will be linked at the root of the image.
        , contents ? []
        # Commands to run in the context of the layer build.
        # The result will not be copied in the Nix store, meaning access rights
        # and other properties stripped by the Nix store are kept.
        , extraCommands ? ""
        , config ? {}
        # Any extra given to `buildLayeredImage`.
        , ...
        }@layerConfig:
        let
          # Increases the layer count.
          maxLayers = prev.maxLayers + 1;
          # Used to get the closure of the config (e.g. Config.Cmd or Config.Env)
          configJSON = writeText "layer-config.json" (
            builtins.toJSON config
          );
          layer = {
            layerNumber = prev.layerNumber + 1;
            inherit maxLayers;
            contents = prev.contents ++ contents;
            currentStorePaths = "${closureInfo { rootPaths = contents ++ [ configJSON ]; }}/store-paths";
            previousStorePaths = "${closureInfo { rootPaths = prev.contents; }}/store-paths";

            image = (dockerTools.buildLayeredImage (layerConfig // {
              inherit name;
              # Layer on top of the previous step.
              fromImage = prev.image;
              # We're consuming only one layer per step, but `buildLayeredImage`
              # assumes there is at least one layer for store paths, and one
              # customization layer.
              maxLayers = maxLayers + 1;
              # Skip the built-in implementation of the copy operation.
              includeStorePaths = false;
              # Since we're skipping the built-in implementation, let's add our store paths:
              extraCommands = ''
                paths() {
                  # Given:
                  #   - currentStorePaths = [ c d e f ]
                  #   - previousStorePaths = [ a b c e ]
                  # This returns [ d f ]
                  # `uniq -u` keeps only unique path entries, and we're duplicating unwanted inputs.
                  #
                  # Skip configJSON, which is used only for its transitive dependencies.
                  (
                    cat "${layer.currentStorePaths}" \
                      "${layer.previousStorePaths}" \
                      "${layer.previousStorePaths}"

                    # Skip inclusion of the config file.
                    echo ${configJSON}
                    echo ${configJSON}
                  ) \
                    | sort \
                    | uniq -u
                }

                echo ":: Building layer #${toString layer.layerNumber}"

                mkdir -p ./"$NIX_STORE"
                paths | while read path; do
                  echo " → Copying '$path' in layer"
                  cp -prf "$path" "./$path"
                done

                ${extraCommands}
              '';
            })).overrideAttrs({ passthru ? {}, ... }: {
              passthru = passthru // {
                inherit layer;
              };
            });
          };
        in
        layer
      )
      (
        # Can we continue from the exposed `layer` in `fromImage`?
        if fromImage ? layer && fromImage.layer ? layerNumber
        then fromImage.layer
        else { contents = []; layerNumber = 0; maxLayers = 1; image = fromImage; }
      )
      layeredContent
    )
    # Export the build artifact (image) from the last step.
    .image
  ;
}
