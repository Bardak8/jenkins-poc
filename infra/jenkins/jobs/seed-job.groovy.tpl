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

    parameters {
        choiceParam('ROLE', ['monitoring', 'app'], 'Type de VM à provisionner')
        choiceParam('TARGET', ['1', '2', '3', '4'], 'VM ciblée (app uniquement, ignoré si ROLE=monitoring)')
        booleanParam('REPLACE', false, 'Détruit et recrée la VM ciblée plutôt que de simplement s\'assurer qu\'elle existe')
    }

    properties {
        pipelineTriggers {
            triggers {
            }
        }
    }
}

pipelineJob('deploy-monitoring') {
    description('Lint + tests + déploiement de la stack Prometheus/Alertmanager sur demo-0 (équivalent générique de monitoring_blagnac).')

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

pipelineJob('deploy-isaac-app') {
    description('Build (kaniko) + déploiement de Isaac-Api dans le namespace apps du cluster Kapsule, déclenché à la publication d\'une release GitHub (pas sur chaque push).')

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('${isaac_git_repo_url}')
                        credentials('${git_credentials_id}')
                    }
                    branch('main')
                }
            }
            scriptPath('JenkinsFIle')
            lightweight(true)
        }
    }

    properties {
        pipelineTriggers {
            triggers {
                genericTrigger {
                    genericVariables {
                        genericVariable {
                            key('RELEASE_TAG')
                            value('$.release.tag_name')
                        }
                        genericVariable {
                            // Nommé WEBHOOK_ACTION, pas ACTION : le pipeline a
                            // son propre paramètre choice nommé ACTION
                            // (build-and-deploy/build-only/deploy-only) ;
                            // avec le même nom ici, la valeur brute du
                            // webhook ("published") écrasait ce paramètre et
                            // faisait sauter les deux stages (when
                            // conditional jamais vrai), constaté en vrai.
                            key('WEBHOOK_ACTION')
                            value('$.action')
                        }
                    }
                    token('${isaac_webhook_token}')
                    causeString('Release $RELEASE_TAG publiée sur Isaac-Api')
                    regexpFilterText('$WEBHOOK_ACTION')
                    regexpFilterExpression('^published$')
                    printPostContent(false)
                    printContributedVariables(false)
                }
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
