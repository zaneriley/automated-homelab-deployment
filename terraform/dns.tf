resource "cloudflare_record" "kabuki_dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.kabuki_subdomain
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "request_dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.request_subdomain
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "speedtest_dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.speedtest_subdomain
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# WWW redirects
resource "cloudflare_record" "www_kabuki_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.kabuki_subdomain}"
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "www_request_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.request_subdomain}"
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "www_speedtest_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.speedtest_subdomain}"
  value   = "${var.nuc1_tunnel_uuid}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# Below are records for domains that do not send email.
resource "cloudflare_record" "spf_record" {
  zone_id = var.cloudflare_zone_id
  name    = "@" # '@' represents the root domain
  type    = "TXT"
  value   = "v=spf1 -all"
}

resource "cloudflare_record" "dmarc_record" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc"
  type    = "TXT"
  value   = "v=DMARC1;p=reject;sp=reject;adkim=s;aspf=s;fo=1;rua=mailto:dmarc-rua@${var.cloudflare_zone_name},mailto:demarc@${var.cloudflare_zone_name}"
}

resource "cloudflare_record" "dkim_record" {
  zone_id = var.cloudflare_zone_id
  name    = "*._domainkey"
  type    = "TXT"
  value   = "v=DKIM1; p="
}

resource "cloudflare_record" "null_mx_record" {
  zone_id   = var.cloudflare_zone_id
  name      = "@" # Empty value for the root domain
  type      = "MX"
  value     = "." # Represents a null MX record
  priority  = 0
}