# ============================================================
# Bootstrap — Outputs
# ============================================================

output "tfstate_bucket_name" {
  description = "Terraform State bucket 名稱，用於 platform/ 的 backend 設定"
  value       = google_storage_bucket.tfstate.name
}

output "tfstate_bucket_url" {
  description = "Terraform State bucket URL"
  value       = google_storage_bucket.tfstate.url
}
