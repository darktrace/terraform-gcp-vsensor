resource "google_service_account" "vsensor" {
  display_name = "Darktrace vSensor Quickstart"
  description  = "Allows permission to Darktrace vSensors for logging/monitoring and to read/write PCAPs to Storage Bucket (if enabled)"
  account_id   = "${local.deployment_id}-sa"
  project      = var.project_id
}

resource "google_project_iam_member" "vsensor" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
  ])
  project = data.google_project.project.number
  role    = each.value
  member  = "serviceAccount:${google_service_account.vsensor.email}"
}

# The vSensor uses S3-compatible (XML API) access to the PCAP bucket, which
# requires a Storage HMAC key. At runtime the vSensor lists existing keys and
# creates one if needed.
#
# NOTE: `storage.hmacKeys` permissions are project-scoped in GCP and cannot be
# bound to a specific bucket or service account.
resource "google_project_iam_custom_role" "vsensor_hmac" {
  count = var.retention_time_days == 0 ? 0 : 1

  project = data.google_project.project.project_id
  # Custom role IDs must be alphanumeric or underscores (no hyphens), so the
  # deployment id (which may contain hyphens) is sanitised.
  role_id     = "${replace(local.deployment_id, "-", "_")}_vsensor_hmac"
  title       = "Darktrace vSensor HMAC Key User"
  description = "Create/list/get Storage HMAC keys only (no delete or update). Used by the Darktrace vSensor for S3-compatible PCAP bucket access."
  permissions = [
    "storage.hmacKeys.create",
    "storage.hmacKeys.list",
    "storage.hmacKeys.get",
  ]
}

resource "google_project_iam_member" "vsensor-hmac" {
  count = var.retention_time_days == 0 ? 0 : 1

  project = data.google_project.project.project_id
  role    = google_project_iam_custom_role.vsensor_hmac[0].id
  member  = "serviceAccount:${google_service_account.vsensor.email}"
}

#IAM policies for Secret Manager Secret
resource "google_secret_manager_secret_iam_member" "update_key" {
  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.update_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_secret_manager_secret_iam_member" "sm_push_token" {
  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.push_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_secret_manager_secret_iam_member" "sm_ossensor_hmac" {
  count = length(var.sm_ossensor_hmac) == 0 ? 0 : 1

  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.ossensor_hmac[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

#IAM policies for Cloud Storage Bucket
resource "google_storage_bucket_iam_member" "object_admin_po" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.objectAdmin"
  member = "projectOwner:${var.project_id}"
}

resource "google_storage_bucket_iam_member" "object_admin_sa" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_storage_bucket_iam_member" "legacy_bucket_owner_po" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.legacyBucketOwner"
  member = "projectOwner:${var.project_id}"
}

resource "google_storage_bucket_iam_member" "legacy_bucket_reader_sa" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.vsensor.email}"
}
