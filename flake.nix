{
  description = "Qt Quick frontend for Anime365";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

      # Package definition as a plain function of pkgs.
      # Used by both the overlay and the packages output.
      mkAnime365 =
        pkgs:
        let
          # `ass` is not in nixpkgs — defined from the pinned wheel in uv.lock
          python = pkgs.python3.override {
            packageOverrides = final: _: {
              ass = final.buildPythonPackage {
                pname = "ass";
                version = "1.0.3";
                format = "wheel";
                src = pkgs.fetchurl {
                  url = "https://files.pythonhosted.org/packages/7a/3d/c51af75f531131d4f575cd8a8ffc8b101d21d80804626c25613f352ec85b/ass-1.0.3-py3-none-any.whl";
                  hash = "sha256-i0bkgcX4Zu7IvoMdYml6ClgDlensyTI5AlzdZny+kbI=";
                };
                doCheck = false;
              };
            };
          };

          pythonEnv = python.withPackages (ps: [
            ps.pyside6
            ps.aiohttp
            ps."aiohttp-socks"
            ps.certifi
            ps.ass
          ]);
        in
        pkgs.stdenv.mkDerivation {
          pname = "anime365";
          version = (fromTOML (builtins.readFile ./pyproject.toml)).project.version;
          src = self;

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.qt6.wrapQtAppsHook
          ];
          buildInputs = [
            pkgs.qt6.qtdeclarative
            pythonEnv
          ];

          dontWrapQtApps = true;

          installPhase = ''
            mkdir -p $out/share/anime365 $out/bin
            cp -r src $out/share/anime365/
            makeWrapper ${pythonEnv}/bin/python $out/bin/anime365 \
              --add-flags "$out/share/anime365/src/main.py" \
              --prefix QML2_IMPORT_PATH ':' "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
              --prefix QML_IMPORT_PATH  ':' "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
              "''${qtWrapperArgs[@]}"

            install -Dm644 /dev/stdin $out/share/applications/anime365.desktop <<EOF
            [Desktop Entry]
            Name=Anime365
            Comment=Watch anime via Anime365
            Exec=anime365
            Icon=anime365
            Terminal=false
            Type=Application
            Categories=AudioVideo;Video;
            EOF

            install -Dm644 resources/icon-512.png \
              $out/share/icons/hicolor/512x512/apps/anime365.png
          '';

          meta = with pkgs.lib; {
            description = "Qt Quick frontend for Anime365";
            license = licenses.unlicense;
            platforms = [
              "x86_64-linux"
              "aarch64-linux"
            ];
            mainProgram = "anime365";
          };
        };

    in
    {
      # Overlay: adds pkgs.anime365 to any nixpkgs instance
      overlays.default = _final: prev: {
        anime365 = mkAnime365 prev;
      };

      # Direct package outputs (for nix build / nix run)
      packages = forAll (pkgs: {
        default = mkAnime365 pkgs;
      });

      # Development shell — keeps the existing uv/pip workflow
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            uv
            cacert
            binutils
          ];

          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
            with pkgs;
            [
              glib
              fontconfig
              freetype
              libGL
              libxkbcommon
              dbus
              zlib
              wayland
              stdenv.cc.cc.lib
              krb5
              nss
              nspr
              cups
              brotli
              libx11
              libxcursor
              libxrandr
              libxi
              libxcb
              libxcb-wm
              libxcb-image
              libxcb-keysyms
              libxcb-render-util
              libxcb-cursor
            ]
          );
        };
      });
    };
}
