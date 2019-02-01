output "phoogle_sa" {
  description = "The SA KEY JSON content.  Store in GOOGLE_CREDENTIALS."
  value       = "${base64decode(google_service_account_key.startup_scripts.private_key)}"
}
