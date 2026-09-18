// Seed job (Job DSL) — définit le pipeline de démonstration en code.
// Chargé par Jenkins Configuration as Code (clé "jobs" de jenkins-casc.yaml.tpl),
// exécuté automatiquement au démarrage du contrôleur : aucune création manuelle
// de job dans l'interface. C'est ce qui rend Jenkins reconstructible from scratch
// depuis ce dépôt (objectif posé dans le dossier Bloc 3, Annexe G).

pipelineJob('deploy-monitoring-vm') {
    description('''
        Pipeline de démonstration du PoC de migration Jenkins.
        Provisionne une VM/conteneur sur le Proxmox hébergé chez OVH
        (via Terraform, provider Proxmox — voir target-infra/) puis y
        déploie une stack de démonstration.
        Ce pipeline est la preuve que Jenkins, une fois migré, sert bien
        à déployer une charge sur un environnement distinct de celui qui
        héberge le contrôleur.
    '''.stripIndent())

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('${git_repo_url}')
                        credentials('${git_credentials_id}')
                    }
                    branch('main')
                }
            }
            scriptPath('Jenkinsfile')
            lightweight(true)
        }
    }

    properties {
        pipelineTriggers {
            triggers {
                // Déclenchement manuel par défaut pour la démonstration.
                // Un trigger SCM polling ou webhook peut être ajouté ici
                // une fois le dépôt distant en place.
            }
        }
    }
}
