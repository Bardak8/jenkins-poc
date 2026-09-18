# Jenkins Configuration as Code — contrôleur du PoC de migration.
# Fusionné par le plugin configuration-as-code avec la config par défaut
# générée par le chart Helm (sécurité admin via Secret Kubernetes,
# non redéfinie ici pour ne pas entrer en conflit).
#
# Ce fichier est un template Terraform (jenkins.tf) : les interpolations
# sont substituées à l'apply, jamais de secret en clair ici.

jenkins:
  systemMessage: >
    PoC de migration Jenkins — soutenance Bloc 5 (Expert en architecture des SI).
    Contrôleur reconstruit intégralement depuis ce dépôt : Terraform (cluster
    Kapsule + Helm) + Jenkins Configuration as Code (ce fichier) + Job DSL
    (jobs/seed-job.groovy.tpl). Aucune action manuelle requise pour reconstruire.
  # numExecutors et labelString sont déjà générés par le chart Helm à partir
  # de controller.numExecutors (voir jenkins.tf) — les redéfinir ici produit
  # un ConfiguratorConflictException (JCasC refuse un champ défini deux fois).

# unclassified.location.url est déjà généré par le chart Helm à partir de
# controller.jenkinsUrl (voir jenkins.tf), même raison que numExecutors.

jobs:
  - script: |
      ${indent(6, seed_job_script)}
