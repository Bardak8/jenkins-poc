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

    parameters {
        string(name: 'VM_COUNT', defaultValue: '2', description: 'Nombre total de VM demo provisionnées (doit correspondre au pipeline provision-demo-vm)')
    }

    environment {
        DEMO_IP_START = '5'
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

        stage('Déployer Traefik + site') {
            steps {
                sh '''
                    mkdir -p /root/.ssh
                    cp /root/.ssh-secret/id_ed25519 /root/.ssh/id_ed25519
                    chmod 600 /root/.ssh/id_ed25519

                    for i in $(seq 1 $((VM_COUNT - 1))); do
                        ip="192.168.1.$((DEMO_IP_START + i))"

                        ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$ip '
                            sudo apt-get update &&
                            sudo apt-get install -y docker.io docker-compose rsync &&
                            sudo mkdir -p /opt/app &&
                            mkdir -p /tmp/app
                        '

                        rsync -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519" -a \
                            deploy/app/docker-compose.yml deploy/app/index.html \
                            admin@$ip:/tmp/app/

                        ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$ip '
                            sudo cp /tmp/app/* /opt/app/ &&
                            cd /opt/app &&
                            sudo docker-compose up -d
                        '
                    done
                '''
            }
        }

        stage('Vérifier') {
            steps {
                sh '''
                    for i in $(seq 1 $((VM_COUNT - 1))); do
                        ip="192.168.1.$((DEMO_IP_START + i))"
                        ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 admin@$ip 'curl -s localhost:80 | head -5'
                    done
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
