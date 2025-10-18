// Jenkinsfile - Declarative pipeline
pipeline {
  agent any

  // Allow turning on/off K8s deploy from job parameters
  parameters {
    booleanParam(name: 'DEPLOY_TO_K8S', defaultValue: false, description: 'If true, deploy to Kubernetes (requires kubeconfig credential)')
  }

  environment {
    // Ensure the pipeline shells see the node/npm installed in /usr/local/bin
    PATH = "/usr/local/bin:${env.PATH}"
    // Docker image name (adjust to your dockerhub repo)
    IMAGE_NAME = "nidarshanmv/myapp"    // <-- EDIT: replace with your DockerHub repo
    IMAGE_TAG  = "${env.BUILD_ID}"
  }

  options {
    // basic options
    timestamps()
    ansiColor('xterm')
    timeout(time: 1, unit: 'HOURS')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'pwd; ls -la'
      }
    }

    stage('Install deps') {
      steps {
        // This runs as the jenkins user; PATH includes /usr/local/bin so node/npm should be found
        sh '''
          echo "node: $(which node || true) $(node -v || true)"
          echo "npm: $(which npm || true) $(npm -v || true)"
        '''
        // If your project is Node.js
        sh '''
          if [ -f package-lock.json ] || [ -f package.json ]; then
            npm ci || npm install
          else
            echo "No package.json found, skipping npm install"
          fi
        '''
      }
    }

    stage('Build Docker image') {
      steps {
        sh 'docker --version || true'
        sh 'cat Dockerfile || true'
        sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }

    stage('Login & Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
            docker push ${IMAGE_NAME}:latest
            docker logout
          '''
        }
      }
    }

    stage('Deploy green (create/update)') {
      when {
        expression { params.DEPLOY_TO_K8S == true }
      }
      steps {
        // Use kubeconfig file credential if provided in Jenkins credentials as file
        withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG_FILE')]) {
          // copy file to workspace KUBECONFIG path
          sh '''
            export KUBECONFIG="$KUBECONFIG_FILE"
            kubectl version --short
            # Replace deployments (use your deployment filenames)
            kubectl apply -f deployment-green.yaml || true
            # ensure service points to green (or do the switch later)
            kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","color":"green"}}}' || true
          '''
        }
      }
    }

    stage('Manual validation & switch traffic') {
      when {
        expression { params.DEPLOY_TO_K8S == true }
      }
      steps {
        input message: "Validate the green deployment and then approve to switch traffic to green", ok: "Switch"
        withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            export KUBECONFIG="$KUBECONFIG_FILE"
            # switch service to green
            kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","color":"green"}}}'
          '''
        }
      }
    }
  } // stages

  post {
    failure {
      echo "Pipeline FAILED — rollback attempt or manual investigation required."
      // Try safe rollback only if kube deploy was attempted
      script {
        if (params.DEPLOY_TO_K8S == true) {
          withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG_FILE')]) {
            sh '''
              export KUBECONFIG="$KUBECONFIG_FILE"
              # attempt to set service back to blue (best-effort)
              kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","color":"blue"}}}' || true
            '''
          }
        }
      }
    }
    success {
      echo "Pipeline finished successfully."
    }
  }
}
