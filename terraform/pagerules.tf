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

resource "cloudflare_page_rule" "redirect_request_to_requests" {
  zone_id = var.cloudflare_zone_id
  target  = "request.${var.cloudflare_zone_name}/*"
  priority = 1
  status = "active"
  actions {
    forwarding_url {
      url = "https://${var.request_subdomain}.${var.cloudflare_zone_name}/$1"
      status_code = 301
    }
  }
}


#### CACHE RULES EVERYTHING AROUND ME #####
resource "cloudflare_ruleset" "bypass_cache_for_video"  {
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

  rules {
    enabled     = true
    expression  = "(http.host ne \"${var.kabuki_subdomain}.${var.cloudflare_zone_name}\")"
    description = "Cache static assets like CSS, JS, and Images"
    action      = "set_cache_settings"
    action_parameters {
      edge_ttl {
        mode    = "override_origin"
        default = 259200 # 3 days in seconds
      }
      browser_ttl {
        mode    = "override_origin"
        default = 604800 # 7 days in seconds
      }
      cache_key {
        ignore_query_strings_order = true
      }
    }
  }
}

