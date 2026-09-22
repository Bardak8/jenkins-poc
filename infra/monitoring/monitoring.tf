locals {
  additional_rules = {
    nodes    = yamldecode(file("${path.module}/rules/nodes.yml"))
    watchdog = yamldecode(file("${path.module}/rules/watchdog.yml"))
  }
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.monitoring_chart_version
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      # Composants de control plane non exposés sur un cluster Kapsule
      # managé (Scaleway gère l'API server, le scheduler, le controller
      # manager et etcd, jamais accessibles au tenant) : sans ces
      # désactivations, kube-prometheus-stack tente quand même de les
      # scraper et déclenche des alertes en permanence pour des
      # composants qui n'existeront jamais dans la découverte de
      # cibles, faux positifs perpétuels constatés en vrai (Cilium
      # remplace aussi kube-proxy ici, mode kube-proxy replacement).
      kubeScheduler         = { enabled = false }
      kubeControllerManager = { enabled = false }
      kubeProxy             = { enabled = false }
      kubeEtcd              = { enabled = false }
      prometheus = {
        prometheusSpec = {
          retention = "6h"
          resources = {
            requests = { cpu = "100m", memory = "512Mi" }
            limits   = { cpu = "500m", memory = "1Gi" }
          }
          storageSpec = {}
          additionalScrapeConfigs = [
            {
              # Fédération plutôt qu'un scrape direct de node-exporter :
              # la Prometheus locale de demo-0 (deploy/monitoring-stack/)
              # scrape déjà node-exporter/pve/blackbox pour ses propres
              # dashboards. Sans fédération, la Prometheus K8s scrapait
              # la même cible une deuxième fois, indépendamment (deux
              # scrapes du même node-exporter, avec deux jeux de labels
              # instance différents selon la Prometheus interrogée —
              # source de confusion constatée en vrai). honor_labels
              # préserve les labels d'origine (job, instance) tels que
              # fixés dans deploy/monitoring-stack/prometheus/jobs/, donc
              # aucun relabel à dupliquer ici.
              job_name      = "federate-demo0"
              honor_labels  = true
              metrics_path  = "/federate"
              params = {
                "match[]" = [
                  "up{job=~\"node-exporter|pve\"}",
                  "{__name__=~\"pve_.+\"}"
                ]
              }
              static_configs = [
                { targets = ["gateway.ci-cd.svc.cluster.local:9090"] }
              ]
            }
          ]
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = { cpu = "20m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
        config = {
          global = {
            # Port 587 (documenté par défaut) est bloqué en sortie depuis
            # Kapsule, comme la plupart des clouds bloquent les ports
            # SMTP sortants par défaut, anti-spam. 2587 est le port de
            # secours de Scaleway pour ce cas précis, vérifié en vrai
            # (banner SMTP + STARTTLS confirmés) avant ce changement.
            smtp_smarthost   = "${scaleway_tem_domain.alerts.smtp_host}:2587"
            smtp_from        = "alerting@${scaleway_tem_domain.alerts.name}"
            smtp_auth_username = scaleway_tem_domain.alerts.smtps_auth_user
            smtp_auth_password = scaleway_iam_api_key.alerting_smtp.secret_key
            smtp_require_tls   = true
          }
          route = {
            receiver = "email-alert"
            group_by = ["alertname"]
            routes = [
              {
                receiver = "email-alert"
                matchers = ["severity=~\"critical|warning\""]
              }
            ]
          }
          receivers = [
            {
              name = "email-alert"
              email_configs = [
                {
                  to          = var.alert_email
                  send_resolved = true
                }
              ]
            }
          ]
        }
      }
      grafana = {
        image = {
          tag = "13.0.9"
        }
        # Les 24 dashboards livrés par le chart sont complets mais génériques
        # et atterrissent à la racine : ils noient les 5 dashboards du PoC,
        # seuls pertinents ici. Repasser à true pour les retrouver (vue par
        # pod, kubelet, API server...) si un diagnostic fin est nécessaire.
        defaultDashboardsEnabled = false
        service = {
          type = var.grafana_service_type
        }
        sidecar = {
          dashboards = {
            folderAnnotation = "grafana_folder"
            # Sans ça, le sidecar dépose bien le JSON dans un
            # sous-dossier interne à son volume partagé, mais le
            # provisioner Grafana par défaut ignore cette arborescence
            # et importe quand même tout à plat dans le dossier General
            # : constaté en vrai (dashboards visibles hors de tout
            # dossier "PoC" malgré l'annotation grafana_folder posée).
            provider = {
              foldersFromFilesStructure = true
            }
          }
        }
        additionalDataSources = [
          {
            name   = "Demo-0 Prometheus"
            uid    = "demo0-prometheus"
            type   = "prometheus"
            url    = "http://gateway.ci-cd.svc.cluster.local:9090"
            access = "proxy"
          }
        ]
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
        persistence = { enabled = false }

        # Grafana envoie ses propres mails, indépendamment d'Alertmanager :
        # c'est justement le point, il doit pouvoir alerter quand Prometheus
        # (et donc Alertmanager) ne répond plus.
        # Le chart refuse par défaut un secret en clair dans ses values.
        # On l'assume ici : Alertmanager passe déjà son mot de passe SMTP de
        # la même manière dans ce même fichier, et Helm stocke de toute façon
        # ces valeurs dans un secret Kubernetes. L'alternative (existingSecret)
        # imposerait de créer le secret avant le chart, donc avant le
        # namespace qu'il crée lui-même : dépendance circulaire à la
        # reconstruction.
        assertNoLeakedSecrets = false

        "grafana.ini" = {
          smtp = {
            enabled      = true
            host         = "smtp.tem.scw.cloud:2587"
            user         = scaleway_tem_domain.alerts.smtps_auth_user
            password     = scaleway_iam_api_key.alerting_smtp.secret_key
            from_address = "alerting@${scaleway_tem_domain.alerts.name}"
            from_name    = "Grafana PoC"
            skip_verify  = false
          }
        }

        # Surveillance de Prometheus PAR Grafana. Prometheus ne peut pas
        # signaler sa propre mort : la règle qui l'annoncerait est évaluée
        # par lui-même. Grafana est un processus distinct qui l'interroge
        # comme source de données — si Prometheus ne répond plus, la requête
        # ne ramène rien et la règle bascule en alerte (noDataState), d'où
        # le mail. C'est le maillon entre l'auto-surveillance de Prometheus
        # et la sonde externe Uptime Kuma (qui, elle, couvre la perte du
        # cluster entier).
        alerting = {
          "contactpoints.yaml" = {
            apiVersion = 1
            contactPoints = [
              {
                orgId = 1
                name  = "mail-poc"
                receivers = [
                  {
                    uid  = "mail-poc-receiver"
                    type = "email"
                    settings = {
                      addresses   = var.alert_email
                      singleEmail = true
                    }
                  }
                ]
              }
            ]
          }

          "policies.yaml" = {
            apiVersion = 1
            policies = [
              {
                orgId          = 1
                receiver       = "mail-poc"
                group_by       = ["alertname"]
                group_wait     = "30s"
                group_interval = "5m"
                repeat_interval = "4h"
              }
            ]
          }

          "rules.yaml" = {
            apiVersion = 1
            groups = [
              {
                orgId    = 1
                name     = "surveillance-prometheus"
                folder   = "PoC"
                interval = "1m"
                rules = [
                  {
                    uid       = "prometheus-injoignable"
                    title     = "Prometheus injoignable depuis Grafana"
                    condition = "seuil"
                    # 2 minutes avant de crier : un redémarrage de pod ne
                    # doit pas déclencher un mail.
                    for = "2m"
                    # Le coeur du dispositif : pas de données = alerte.
                    noDataState  = "Alerting"
                    execErrState = "Alerting"
                    labels = {
                      severity = "critical"
                    }
                    annotations = {
                      summary     = "Grafana n'obtient plus de réponse de Prometheus"
                      description = "La source de données Prometheus du cluster ne répond plus depuis plus de 2 minutes. Prometheus étant hors service, il ne peut pas signaler lui-même sa panne : cette alerte est émise par Grafana, processus distinct."
                    }
                    data = [
                      {
                        refId         = "requete"
                        relativeTimeRange = { from = 300, to = 0 }
                        datasourceUid = "prometheus"
                        model = {
                          refId   = "requete"
                          # Le job porte le nom de la release Helm en préfixe
                          # (monitoring-kube-prometheus-prometheus) : expression
                          # ancrée sur le suffixe pour survivre à un renommage.
                          # Avec le mauvais label, la requête ne ramenait rien,
                          # donc noDataState faisait croire à une panne.
                          expr    = "up{job=~\".*kube-prometheus-prometheus\"}"
                          instant = true
                          intervalMs    = 1000
                          maxDataPoints = 43200
                        }
                      },
                      {
                        refId         = "seuil"
                        relativeTimeRange = { from = 300, to = 0 }
                        datasourceUid = "__expr__"
                        model = {
                          refId      = "seuil"
                          type       = "threshold"
                          expression = "requete"
                          conditions = [
                            {
                              evaluator = { type = "lt", params = [1] }
                            }
                          ]
                        }
                      }
                    ]
                  }
                ]
              }
            ]
          }
        }
      }
      kubeStateMetrics = {
        resources = {
          requests = { cpu = "20m", memory = "64Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
      nodeExporter = {
        resources = {
          requests = { cpu = "20m", memory = "32Mi" }
          limits   = { cpu = "50m", memory = "64Mi" }
        }
      }
      additionalPrometheusRulesMap = local.additional_rules
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc]
}

resource "kubernetes_ingress_v1" "grafana" {
  count = var.grafana_hostname != "" ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = "monitoring"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.grafana_hostname]
      secret_name = "grafana-tls"
    }

    rule {
      host = var.grafana_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "monitoring-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.monitoring]
}
