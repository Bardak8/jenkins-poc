pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: deploy
                    image: alpine:3.20
                    command: ["cat"]
                    tty: true
                    securityContext:
                      capabilities:
                        add: ["NET_ADMIN"]
                    volumeMounts:
                    - name: wireguard-config
                      mountPath: /etc/wireguard-secret
                      readOnly: true
                    - name: ssh-key
                      mountPath: /root/.ssh-secret
                      readOnly: true
                  volumes:
                  - name: wireguard-config
                    secret:
                      secretName: deploy-wireguard
                  - name: ssh-key
                    secret:
                      secretName: deploy-ssh-key
                      defaultMode: 0400
            '''
            defaultContainer 'deploy'
        }
    }

    stages {
        stage('Préparer les outils') {
            steps {
                sh 'apk add --no-cache wireguard-tools openssh-client rsync'
            }
        }

        stage('Monter le tunnel') {
            steps {
                sh '''
                    mkdir -p /etc/wireguard
                    cp /etc/wireguard-secret/wg0.conf /etc/wireguard/wg0.conf
                    chmod 600 /etc/wireguard/wg0.conf
                    wg-quick up wg0
                '''
            }
        }

        stage('Découvrir les cibles') {
            steps {
                script {
                    def targets = []
                    for (i = 1; i <= 4; i++) {
                        def ip = "192.168.1.${5 + i}"
                        def alive = sh(script: "ping -c1 -W1 ${ip} > /dev/null 2>&1", returnStatus: true) == 0
                        if (alive) {
                            targets << ip
                        }
                    }
                    if (targets.isEmpty()) {
                        error('Aucune VM app détectée (192.168.1.6 à .9 injoignables). Lance provision-demo-vm avec ROLE=app avant.')
                    }
                    env.AVAILABLE_TARGETS = targets.join('\n')
                }
            }
        }

        stage('Choisir la cible') {
            steps {
                script {
                    env.TARGET_IP = input(
                        message: 'VM app détectées en direct, laquelle déployer ?',
                        parameters: [choice(name: 'TARGET_IP', choices: env.AVAILABLE_TARGETS, description: '')]
                    )
                }
            }
        }

        stage('Déployer Traefik + site') {
            steps {
                sh '''
                    mkdir -p /root/.ssh
                    cp /root/.ssh-secret/id_ed25519 /root/.ssh/id_ed25519
                    chmod 600 /root/.ssh/id_ed25519

                    ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$TARGET_IP '
                        sudo apt-get update &&
                        sudo apt-get install -y docker.io docker-compose rsync &&
                        sudo mkdir -p /opt/app &&
                        mkdir -p /tmp/app
                    '

                    rsync -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519" -a \
                        deploy/app/docker-compose.yml deploy/app/index.html \
                        admin@$TARGET_IP:/tmp/app/

                    ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$TARGET_IP '
                        sudo cp /tmp/app/* /opt/app/ &&
                        cd /opt/app &&
                        sudo docker-compose up -d
                    '
                '''
            }
        }

        stage('Vérifier') {
            steps {
                sh '''
                    ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$TARGET_IP 'curl -s localhost:80 | head -5'
                '''
            }
        }
    }

    post {
        always {
            sh 'wg-quick down wg0 || true'
        }
    }
}
