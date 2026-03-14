{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  gcr_4,
  glib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gnome-ssh-askpass4";
  version = "10.2p1"; # Match openssh version

  src = fetchurl {
    url = "mirror://openbsd/OpenSSH/portable/openssh-${finalAttrs.version}.tar.gz";
    hash = "sha256-zMQsBBmTeVkmP6Hb0W2vwYxWuYTANWLSk3zlamD3mLI=";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    gcr_4
    glib
  ];

  # Only build gnome-ssh-askpass4 from contrib
  buildPhase = ''
    runHook preBuild
    make -C contrib gnome-ssh-askpass4
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 contrib/gnome-ssh-askpass4 $out/bin/gnome-ssh-askpass4
    runHook postInstall
  '';

  # Skip configure since we're only building from contrib
  dontConfigure = true;

  meta = {
    homepage = "https://www.openssh.com/";
    description = "GNOME SSH passphrase dialog for OpenSSH using GCR 4";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.linux;
    mainProgram = "gnome-ssh-askpass4";
  };
})
