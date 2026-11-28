# AWS's extension of the Linux kernel for Nitro Sandboxes, for nixpkgs' 6.18:
# the Nitro Enclaves driver's sandbox support, which parents need to launch
# sandboxes, and the virtio device memory buffers (DMB) and paravirtual clock
# that guests need in confidential mode.
#
# AWS doesn't publish it as a patch series; it ships in Amazon Linux 2023's
# kernel6.18 package. Its source RPM carries it as a single patch, which
# applies to nixpkgs' 6.18 kernel as is.
{
  runCommand,
  fetchurl,
  buildPackages,
}:
let
  srpm = fetchurl {
    url = "https://cdn.amazonlinux.com/al2023/blobstore/cbb9be49c69897a31d4ff653bf48ad68dc6a2e95df6c18c26cd92549c752c857/kernel6.18-6.18.62-127.179.amzn2023.src.rpm";
    sha256 = "cbb9be49c69897a31d4ff653bf48ad68dc6a2e95df6c18c26cd92549c752c857";
  };
in
runCommand "nitro-enclaves-extension.patch" { nativeBuildInputs = [ buildPackages.libarchive ]; } ''
  bsdtar -xOf ${srpm} 0144-nitro_enclaves-Amazon-Nitro-Enclaves-extension-port-.patch > $out
''
