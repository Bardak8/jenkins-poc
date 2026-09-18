pipelineJob('provision-demo-vm') {
    description('Provisionne les VM de démo sur Proxmox (OVH) via Terraform.')

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
            scriptPath('deploy/Jenkinsfile.provision')
            lightweight(true)
        }
    }

    properties {
        pipelineTriggers {
            triggers {
            }
        }
    }
}

pipelineJob('deploy-monitoring') {
    description('Déploie node_exporter sur la VM demo-0 via tunnel WireGuard + SSH.')

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
            scriptPath('deploy/Jenkinsfile.monitoring')
            lightweight(true)
        }
    }

    properties {
        pipelineTriggers {
            triggers {
            }
        }
    }
}

pipelineJob('deploy-app') {
    description('Déploie Traefik + un site de démo sur les VM demo-1 et suivantes.')

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
            scriptPath('deploy/Jenkinsfile.app')
            lightweight(true)
        }
    }

    properties {
        pipelineTriggers {
            triggers {
            }
        }
    }
}
