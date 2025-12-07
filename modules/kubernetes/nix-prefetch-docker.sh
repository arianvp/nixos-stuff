#!/usr/bin/env bash
# Array of images: "image:tag"
images=(
  "registry.k8s.io/pause:3.10.1"
  "registry.k8s.io/e2e-test-images/nginx:1.14-2"
  "registry.k8s.io/e2e-test-images/busybox:1.29-2"
  "registry.k8s.io/e2e-test-images/httpd:2.4.39-4"
  "registry.k8s.io/e2e-test-images/nonewprivs:1.3"
  "gcr.io/k8s-staging-cri-tools/hostnet-nginx-arm64:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-predefined-group:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-tag:test"
  "gcr.io/k8s-staging-cri-tools/test-image-tag:all"
  "gcr.io/k8s-staging-cri-tools/test-image-latest:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-user-uid:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-1:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-2:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-3:latest"
  "gcr.io/k8s-staging-cri-tools/test-image-tags:1"
  "gcr.io/k8s-staging-cri-tools/test-image-tags:2"
  "gcr.io/k8s-staging-cri-tools/test-image-tags:3"
  "gcr.io/k8s-staging-cri-tools/test-image-digest@sha256:9700f9a2f5bf2c45f2f605a0bd3bce7cf37420ec9d3ed50ac2758413308766bf"
)

ARCH="arm64"
OS="linux"

for image_spec in "${images[@]}"; do
  # Check if image uses digest (@) or tag (:)
  if [[ "$image_spec" == *"@"* ]]; then
    # Digest-based reference
    IFS='@' read -r image digest <<< "$image_spec"
    tag_or_digest="$digest"
    display_ref="$image@$digest"
    # Use first 12 chars of digest for directory name
    short_digest="${digest:0:12}"
    output_path="images/${image}-${short_digest}"
  else
    # Tag-based reference
    IFS=':' read -r image tag <<< "$image_spec"
    tag_or_digest="$tag"
    display_ref="$image:$tag"
    # Sanitize tag for use in directory name (replace special chars with -)
    safe_tag="${tag//[^a-zA-Z0-9._-]/-}"
    output_path="images/${image}-${safe_tag}"
  fi

  # Create directory
  mkdir -p "$output_path"

  echo "Fetching $display_ref..."
  nix run nixpkgs#nix-prefetch-docker -- --arch "$ARCH" --os "$OS" "$image" "$tag_or_digest" > "$output_path/default.nix"
done
