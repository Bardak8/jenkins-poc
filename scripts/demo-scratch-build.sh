#!/usr/bin/env bash
# Scénario vidéo : construction complète depuis zéro, cluster à 3 nœuds
# multi-zone dès le premier apply (pas le mode 1 nœud par défaut).
# `infra/state-backend/` n'est jamais touché (voir README, il ne doit
# jamais dépendre d'un test de reconstruction). `infra/backup/` non plus
# côté destroy : son bucket accumule l'historique réel des sauvegardes,
# le vider à chaque reconstruction serait absurde (les sauvegardes
# doivent justement survivre à ce genre d'exercice). Il est réappliqué
# (pas détruit) à l'étape 3 pour recréer ses secrets Kubernetes.
#
# infra/ingress : les 2 scaleway_lb_ip (ingress + ingress_secondary)
# sont volontairement exclues du destroy, ciblé sur tout le reste du
# module. Le but d'une IP "réservée" est justement de ne pas changer ;
# la laisser dans le même destroy que le reste de l'ingress la
# recréait à chaque scratch-build (constaté en vrai : DNS qui pointe
# vers une IP morte après reconstruction). Elle reste donc en state
# tout du long, et le helm_release ingress_nginx la retrouve telle
# quelle lors du re-apply à l'étape 3.
#
# infra/apps : même logique pour scaleway_registry_namespace.apps. Le
# registre d'images n'a aucune raison de dépendre du cycle de vie du
# cluster (comme le bucket de sauvegarde) ; le vider à chaque
# reconstruction forçait un rebuild Jenkins manuel juste pour que
# l'appli redevienne joignable, alors que rien ne l'imposait.
#
# infra/monitoring : même logique pour scaleway_tem_domain.alerts. Un
# domaine d'envoi mail a des enregistrements DNS publiés à la main chez
# le registrar (SPF/DKIM/DMARC/MX) ; le recréer régénère une nouvelle
# clé DKIM que le DNS existant ne reflète plus, cassant l'alerting mail
# jusqu'à mise à jour manuelle du DNS (constaté en vrai). Exclu du
# destroy, jamais recréé donc jamais désynchronisé du DNS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCW_PROFILE="newprofile"

echo "==> [1/3] Destruction complète (hors state-backend, backup, IP, registre et domaine mail réservés)"
export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
# Garde-fou Longhorn : refuse de se désinstaller tant que ce flag n'est
# pas explicitement passé à true (anti-suppression-accidentelle).
kubectl patch settings.longhorn.io deleting-confirmation-flag -n longhorn-system --type merge -p '{"value":"true"}' 2>/dev/null || true
for module in relay jenkins cluster; do
    echo "  -- infra/$module"
    (cd "$ROOT/infra/$module" && terraform destroy -auto-approve)
done

echo "  -- infra/monitoring (tout sauf le domaine mail)"
(cd "$ROOT/infra/monitoring" && terraform destroy -auto-approve \
    -target=kubernetes_config_map.dashboard_demo_poc \
    -target=kubernetes_config_map.dashboard_demo_stack \
    -target=kubernetes_config_map.dashboard_proxmox \
    -target=kubernetes_ingress_v1.grafana \
    -target=helm_release.monitoring \
    -target=scaleway_iam_api_key.alerting_smtp \
    -target=scaleway_iam_policy.alerting_smtp \
    -target=scaleway_iam_application.alerting_smtp)

echo "  -- infra/apps (tout sauf le registre)"
(cd "$ROOT/infra/apps" && terraform destroy -auto-approve \
    -target=helm_release.cnpg_operator \
    -target=kubernetes_secret.isaac_db_credentials_basic_auth \
    -target=kubectl_manifest.isaac_postgres_cluster \
    -target=kubernetes_deployment.isaac_fansite \
    -target=kubernetes_service.isaac_fansite \
    -target=kubernetes_ingress_v1.isaac_fansite \
    -target=kubernetes_horizontal_pod_autoscaler_v2.isaac_fansite \
    -target=kubernetes_network_policy_v1.apps_default_deny_ingress \
    -target=kubernetes_network_policy_v1.allow_ingress_to_isaac_fansite \
    -target=kubernetes_network_policy_v1.allow_to_isaac_postgres \
    -target=kubernetes_network_policy_v1.allow_cnpg_operator_status \
    -target=kubernetes_network_policy_v1.allow_monitoring_scrape_isaac_postgres \
    -target=kubernetes_secret.isaac_db_credentials \
    -target=kubernetes_role.jenkins_deploy_apps \
    -target=kubernetes_role_binding.jenkins_deploy_apps \
    -target=scaleway_secret.isaac_db_password \
    -target=scaleway_secret_version.isaac_db_password \
    -target=kubernetes_namespace.apps)

echo "  -- infra/ingress (tout sauf les IP réservées)"
(cd "$ROOT/infra/ingress" && terraform destroy -auto-approve \
    -target=kubernetes_manifest.letsencrypt_prod \
    -target=helm_release.cert_manager \
    -target=helm_release.ingress_nginx \
    -target=kubernetes_service.ingress_nginx_nodeport \
    -target=scaleway_instance_security_group_rules.kapsule_nodeport \
    -target=scaleway_lb_frontend.ingress_http \
    -target=scaleway_lb_frontend.ingress_https \
    -target=scaleway_lb_backend.ingress_http \
    -target=scaleway_lb_backend.ingress_https \
    -target=scaleway_lb.ingress_secondary)

echo
echo "==> [2/3] Cluster à 3 nœuds dès le premier apply (ha_enabled=true)"
(cd "$ROOT/infra/cluster" && terraform apply -auto-approve -var="ha_enabled=true")

echo
echo "==> [3/3] Reconstruction du reste (config only, aucune donnée à restaurer ici)"
for module in jenkins relay ingress apps monitoring backup; do
    echo "  -- infra/$module"
    (cd "$ROOT/infra/$module" && terraform init -input=false -upgrade=false >/dev/null && terraform apply -auto-approve)
done

echo

echo "==> Nœuds (3 zones)"
kubectl get nodes -L topology.kubernetes.io/zone

echo
echo "==> isaac-postgres (primaire + réplique, doivent être sur 2 nœuds différents)"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide

echo
"$ROOT/scripts/get-urls.sh"
