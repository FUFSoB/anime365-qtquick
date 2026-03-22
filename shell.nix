{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    uv
    cacert
  ];

  SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
    # Qt / PySide6 runtime dependencies
    glib
    fontconfig
    freetype
    libGL
    libxkbcommon
    dbus
    zlib
    wayland
    stdenv.cc.cc.lib # libstdc++
    krb5
    nss
    nspr
    cups
    brotli

    # X11 / XCB
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
  ]);
}
