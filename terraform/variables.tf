variable "cloudflare_api_token" {
  description = "API token for Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID for your domain"
  type        = string
}

variable "cloudflare_zone_name" {
  description = "The primary domain name for the Cloudflare zone"
  type        = string
}

variable "nuc1_tunnel_uuid" {
  description = "The Cloudflare tunnel hostname for NUC1"
  type        = string
}

variable "nuc2_tunnel_uuid" {
  description = "The Cloudflare tunnel hostname for NUC2"
  type        = string
}

variable "remote_tunnel_uuid" {
  description = "The Cloudflared tunnel hostname for the remote server used for uptime status"
  type        = string
}

variable "kabuki_subdomain" {
  description = "The subdomain name for Kabuki"
  type        = string
}

variable "request_subdomain" {
  description = "The subdomain name for request"
  type        = string
}

variable "speedtest_subdomain" {
  description = "The subdomain name for the Speedtest server"
  type        = string
}