output "bucket_name" {
  description = "Nom du bucket Object Storage contenant les sauvegardes"
  value       = scaleway_object_bucket.backups.name
}

output "next_step" {
  description = "Étapes suivantes"
  value       = "Les CronJobs 'jenkins-home-backup-to-s3' (ci-cd) et 'isaac-postgres-backup-to-s3' (apps) tournent chaque nuit à 3h. Pour tester immédiatement sans attendre : kubectl create job --from=cronjob/jenkins-home-backup-to-s3 test-backup-jenkins -n ci-cd (idem pour isaac-postgres-backup-to-s3 -n apps)."
}
