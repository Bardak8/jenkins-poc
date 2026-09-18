jenkins:
  systemMessage: >
    PoC de migration Jenkins — soutenance Bloc 5.
    Reconstruit depuis ce dépôt : Terraform + Helm + JCasC + Job DSL.

jobs:
  - script: |
      ${indent(6, seed_job_script)}
