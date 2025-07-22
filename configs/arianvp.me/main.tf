# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "arianvp" {
  image   = "nixos-25.05"
  name    = "arianvp-me"
  region  = "ams1"
  size    = "s-1vcpu-1gb"
}
