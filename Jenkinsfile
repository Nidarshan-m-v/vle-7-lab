// Jenkinsfile - Blue/Green pipeline (Node.js example)
// Replace <DOCKERHUB_USER> with your Docker Hub username before committing.

pipeline {
  agent any

  environment {
    DOCKERHUB_USER = 'nidarshanmv'              // <-- REPLACE this
    IMAGE          = "${DOCKERHUB_USER}/myapp:${BUILD_NUMBER}"
    KUBECTL        = '/usr/local/bin/kubectl'        // adjust if kubectl is at another path
    DEPLOY_BLUE    = 'deployment-blue.yaml'
    DEPLOY_GREEN   = 'deployment-green.yaml'
    SERVICE_FILE   = 'service.yaml'
    DEPLOY_BLUE_NAME  = 'myapp-blue'
    DEPLOY_GREEN_NAME = 'myapp-green'
    SERVICE_NAME      = 'myapp-service'
  }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {
    stage('Prepare / Checkout') {
      steps {
        // declarative pipeline already performs a checkout, but explicitly ensure we use the same revision
        checkout scm
        sh 'echo "Workspace: $(pwd)"; ls -la'
      }
    }

    stage('Install deps') {
      steps {
        // Node app example - adjust if using Maven/Gradle for Java
        sh 'npm ci || npm install'
      }
    }

    stage('Build Docker image') {
      steps {
        sh 'docker build -t $IMAGE .'
      }
    }

    stage('Login & Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
          sh 'docker push $IMAGE'
          sh 'docker logout || true'
        }
      }
    }

    stage('Deploy green (create/update)') {
      steps {
        // apply green deployment and set the image
        sh '''
$KUBECTL apply -f $DEPLOY_GREEN || true
$KUBECTL set image deployment/$DEPLOY_GREEN_NAME myapp=$IMAGE --record || true
$KUBECTL rollout status deployment/$DEPLOY_GREEN_NAME --timeout=180s || true
'''
      }
    }

    stage('Manual validation & switch traffic') {
      steps {
        // manual verification: approve to switch service selector to green
        timeout(time: 30, unit: 'MINUTES') {
          input message: "Validate the GREEN deployment and approve switching traffic to GREEN?"
        }
        // patch the service selector to point to green
        sh '$KUBECTL patch service $SERVICE_NAME -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"color\":\"green\"}}}"'
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully — GREEN is live (if switched)."
    }
    failure {
      echo "Pipeline FAILED — attempting safe rollback (switch service back to BLUE)."
      sh '$KUBECTL patch service $SERVICE_NAME -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"color\":\"blue\"}}}" || true'
      error("Pipeline failed - manual investigation required.")
    }
  }
}
