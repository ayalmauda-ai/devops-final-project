pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'ayalm'
        IMAGE_NAME      = 'engine'
        DOCKER_CRED_ID  = 'dockerhub-token'
        EMAIL_RECIPIENT = 'ayal.mauda@gmail.com'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    def changed = sh(
                        script: "git diff --name-only HEAD~1 HEAD || true",
                        returnStdout: true
                    ).trim()

                    def relevant = changed.split('\n').any { f ->
                        f.startsWith('engine/') ||
                        f == 'docker/engine.Dockerfile' ||
                        f == 'VERSION'
                    }

                    if (!relevant) {
                        currentBuild.result = 'NOT_BUILT'
                        error("No engine-related changes detected. Skipping.")
                    }
                }
            }
        }

        stage('Read Version') {
            steps {
                script {
                    env.VERSION = readFile('VERSION').trim()
                    echo "Building version: ${env.VERSION}"
                }
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build \
                        --build-arg VERSION=${env.VERSION} \
                        -f docker/engine.Dockerfile \
                        -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${env.VERSION} \
                        -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest \
                        .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: DOCKER_CRED_ID,
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_TOKEN'
                )]) {
                    sh """
                        echo "${DH_TOKEN}" | docker login -u "${DH_USER}" --password-stdin
                        docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${env.VERSION}
                        docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest
                        docker logout
                    """
                }
            }
        }
    }

    post {
        failure {
            mail(
                to: EMAIL_RECIPIENT,
                subject: "FAILED: Engine CI - Build #${env.BUILD_NUMBER}",
                body: "Build failed.\n\nJob: ${env.JOB_NAME}\nBuild: ${env.BUILD_URL}"
            )
        }
        success {
            echo "Engine image ${DOCKER_HUB_USER}/${IMAGE_NAME}:${env.VERSION} pushed successfully."
        }
    }
}
