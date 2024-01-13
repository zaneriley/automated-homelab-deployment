resource "cloudflare_page_rule" "force_ssl" {
  zone_id = var.cloudflare_zone_id
  target  = "*.${var.cloudflare_zone_name}/*"
  actions {
    always_use_https = true
  }
  priority = 1
}

resource "cloudflare_page_rule" "www_redirect" {
  zone_id  = var.cloudflare_zone_id
  target   = "www.*.${var.cloudflare_zone_name}/*"
  priority = 1
  status   = "active"

  actions {
    forwarding_url {
      status_code = 301
      url         = "https://$1.${var.cloudflare_zone_name}/$2"
    }
  }
}


#### CACHE RULES EVERYTHING AROUND ME #####
resource "cloudflare_ruleset" "bypass_cache_for_video" {
  zone_id     = var.cloudflare_zone_id
  name        = "Bypass cache for video"
  description = "Cache control rules for incoming requests"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    enabled   = true
    expression  = "(http.host eq \"${var.kabuki_subdomain}.${var.cloudflare_zone_name}\")"
    description = "Bypass cache for kabuki video"
    action    = "set_cache_settings"
    action_parameters {
      cache       = false
    }
  }
}
