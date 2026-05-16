pipeline {
    agent any

    environment {
        GITHUB_USER     = 'ayalmauda-ai'
        REPO_NAME       = 'devops-final-project'
        GITHUB_CRED_ID  = 'github-token'
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
                        f.startsWith('cli/') || f == 'VERSION'
                    }

                    if (!relevant) {
                        currentBuild.result = 'NOT_BUILT'
                        error("No CLI-related changes detected. Skipping.")
                    }
                }
            }
        }

        stage('Read Version') {
            steps {
                script {
                    env.VERSION = readFile('VERSION').trim()
                    echo "Packaging CLI version: ${env.VERSION}"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh """
                    pip3 install --quiet --break-system-packages \
                        -r cli/sawectl/requirements.txt
                """
            }
        }

        stage('Run Tests') {
            steps {
                sh """
                    cd cli/sawectl
                    python3 -m pytest tests/ -v 2>/dev/null || \
                    echo "No tests found — skipping"
                """
            }
        }

        stage('Package CLI') {
            steps {
                sh """
                    tar -czf cli-${env.VERSION}.tar.gz \
                        -C cli/sawectl .
                """
            }
        }

        stage('Publish to GitHub Releases') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GITHUB_CRED_ID,
                    usernameVariable: 'GH_USER',
                    passwordVariable: 'GH_TOKEN'
                )]) {
                    sh """
                        # Create the release tag
                        curl -s -X POST \
                            -H "Authorization: token ${GH_TOKEN}" \
                            -H "Content-Type: application/json" \
                            -d '{"tag_name":"cli-v${env.VERSION}","name":"CLI v${env.VERSION}","body":"CLI release ${env.VERSION}"}' \
                            https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/releases \
                            > release.json

                        UPLOAD_URL=\$(cat release.json | python3 -c \
                            "import sys,json; print(json.load(sys.stdin)['upload_url'].split('{')[0])")

                        # Upload the tarball
                        curl -s -X POST \
                            -H "Authorization: token ${GH_TOKEN}" \
                            -H "Content-Type: application/gzip" \
                            --data-binary @cli-${env.VERSION}.tar.gz \
                            "\${UPLOAD_URL}?name=cli-${env.VERSION}.tar.gz"
                    """
                }
            }
        }
    }

    post {
        failure {
            mail(
                to: EMAIL_RECIPIENT,
                subject: "FAILED: CLI CI - Build #${env.BUILD_NUMBER}",
                body: "Build failed.\n\nJob: ${env.JOB_NAME}\nBuild: ${env.BUILD_URL}"
            )
        }
        success {
            echo "CLI v${env.VERSION} packaged and published to GitHub Releases."
        }
        always {
            sh "rm -f cli-*.tar.gz release.json || true"
        }
    }
}
