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
# L'ordre compte : tous les modules qui parlent au Kubernetes doivent être
# détruits AVANT les pools de nœuds. Un cluster Kapsule sans aucun nœud
# passe en statut "pool_required" et son endpoint d'API devient injoignable
# (constaté en vrai : timeout puis "no such host" sur l'API) — les destroy
# suivants échouaient alors tous. infra/cluster part donc en dernier.
for module in relay jenkins; do
    echo "  -- infra/$module"
    (cd "$ROOT/infra/$module" && terraform destroy -auto-approve)
done

echo "  -- infra/monitoring (tout sauf le domaine mail)"
(cd "$ROOT/infra/monitoring" && terraform destroy -auto-approve \
    -target=kubernetes_config_map.dashboard_demo_stack \
    -target=kubernetes_config_map.dashboard_proxmox \
    -target=kubernetes_config_map.dashboard_watchdog \
    -target=kubernetes_config_map.dashboard_proxmox_vm_select \
    -target=kubernetes_ingress_v1.grafana \
    -target=helm_release.monitoring \
    -target=scaleway_iam_api_key.alerting_smtp \
    -target=scaleway_iam_policy.alerting_smtp \
    -target=scaleway_iam_application.alerting_smtp)

echo "  -- infra/apps : d'abord le cluster Postgres, seul"
(cd "$ROOT/infra/apps" && terraform destroy -auto-approve \
    -target=kubectl_manifest.isaac_postgres_cluster)

# Terraform rend la main dès que l'API accepte la suppression, mais CNPG
# continue d'arrêter ses pods en arrière-plan. Si l'opérateur est détruit
# pendant ce temps, plus personne ne retire le finaliseur pvc-protection
# des volumes, et le namespace reste bloqué en Terminating indéfiniment
# (constaté en vrai : destroy échoué sur "context deadline exceeded").
echo "     attente de la disparition réelle des pods Postgres"
for i in $(seq 1 60); do
    PGPODS=$(kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres --no-headers 2>/dev/null | wc -l)
    [ "${PGPODS:-0}" = "0" ] && break
    echo "       ${PGPODS} pod(s) encore présent(s)"
    sleep 5
done
# Filet : si des pods restent figés en Succeeded, ils bloquent leurs PVC.
kubectl delete pods -n apps -l cnpg.io/cluster=isaac-postgres \
    --grace-period=0 --force --ignore-not-found >/dev/null 2>&1 || true

echo "  -- infra/apps (le reste, sauf le registre)"
(cd "$ROOT/infra/apps" && terraform destroy -auto-approve \
    -target=helm_release.cnpg_operator \
    -target=kubernetes_secret.isaac_db_credentials_basic_auth \
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

echo "  -- infra/cluster (les pools de nœuds, en dernier : l'API devient injoignable ensuite)"
(cd "$ROOT/infra/cluster" && terraform destroy -auto-approve)

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

echo "==> Attente que tout soit réellement en service"
# Sans cette attente, la vérification ci-dessous s'affichait pendant que les
# pods démarraient encore (Init/Pending) : la preuve de placement multi-zone
# n'était donc pas visible à l'écran. On attend que CNPG ait ses 2 instances.
kubectl rollout status statefulset/jenkins -n ci-cd --timeout=600s || true
for i in $(seq 1 40); do
    PGREADY=$(kubectl get cluster isaac-postgres -n apps -o jsonpath='{.status.readyInstances}' 2>/dev/null)
    echo "  isaac-postgres : ${PGREADY:-0}/2 instances prêtes"
    [ "${PGREADY:-0}" = "2" ] && break
    sleep 15
done

echo
echo "==> Nœuds (3 zones)"
kubectl get nodes -L topology.kubernetes.io/zone

echo
echo "==> isaac-postgres (primaire + réplique, doivent être sur 2 nœuds différents)"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres \
    -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,ROLE:.metadata.labels.role'

echo
"$ROOT/scripts/get-urls.sh"
