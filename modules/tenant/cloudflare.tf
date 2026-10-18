# ── Cloudflare: per-tenant tunnel + optional assets Worker ──

data "cloudflare_zone" "zone" {
  name = var.zone
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "app" {
  account_id = var.cf_account_id
  name       = "${var.name}-app"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "app" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.app.id

  config {
    ingress_rule {
      hostname = local.fqdn
      service  = local.app_service
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.zone.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.app.cname
  proxied = true
  ttl     = 1
}

# ── Assets Worker (optional) ──────────────────────────────
# Serves a private bucket over Cloudflare. Storage backend is either the OCI
# S3-compatible API (SigV4 with the tenant's customer secret key) or a native
# R2 bucket binding (worker_storage_backend = "r2").

resource "cloudflare_workers_script" "assets" {
  count              = var.worker_enabled ? 1 : 0
  account_id         = var.cf_account_id
  name               = "${var.name}-assets"
  content            = file(coalesce(var.worker_script_path, "${path.module}/files/worker.js"))
  compatibility_date = "2023-01-01"

  dynamic "plain_text_binding" {
    for_each = var.worker_storage_backend == "oci" ? {
      OCI_NAMESPACE = data.oci_objectstorage_namespace.ns.namespace
      OCI_REGION    = var.region
      OCI_BUCKET    = var.assets_bucket
    } : {}
    content {
      name = plain_text_binding.key
      text = plain_text_binding.value
    }
  }
  dynamic "secret_text_binding" {
    for_each = var.worker_storage_backend == "oci" ? {
      OCI_S3_ACCESS_KEY = oci_identity_customer_secret_key.tenant.id
      OCI_S3_SECRET_KEY = oci_identity_customer_secret_key.tenant.key
    } : {}
    content {
      name = secret_text_binding.key
      text = secret_text_binding.value
    }
  }
  dynamic "r2_bucket_binding" {
    for_each = var.worker_storage_backend == "r2" ? [var.r2_bucket_name] : []
    content {
      name        = var.worker_r2_binding_name
      bucket_name = r2_bucket_binding.value
    }
  }
  dynamic "secret_text_binding" {
    for_each = var.worker_secret_bindings
    content {
      name = secret_text_binding.key
      text = secret_text_binding.value
    }
  }
}

resource "cloudflare_workers_domain" "assets" {
  count      = var.worker_enabled ? 1 : 0
  account_id = var.cf_account_id
  zone_id    = data.cloudflare_zone.zone.zone_id
  hostname   = local.assets_fqdn
  service    = cloudflare_workers_script.assets[0].name
}
