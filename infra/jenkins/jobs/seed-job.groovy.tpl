pipelineJob('provision-demo-vm') {
    description('Provisionne la VM de démo sur Proxmox (OVH) via Terraform.')

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

pipelineJob('deploy-node-exporter') {
    description('Déploie node_exporter sur la VM de démo via tunnel WireGuard + SSH.')

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
            scriptPath('deploy/Jenkinsfile.deploy')
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
