pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "nidarshanmv/myapp"
    }

    stages {
        stage('Clone Code') {
            steps {
                git 'https://github.com/Nidarshan-m-v/vle-7-lab.git'
            }
        }

        stage('Build') {
            steps {
                sh 'npm install'
            }
        }

        stage('Docker Build & Push') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:$BUILD_NUMBER .'
                sh 'docker push $DOCKER_IMAGE:$BUILD_NUMBER'
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                kubectl apply -f deployment-blue.yaml
                kubectl apply -f service.yaml
                '''
            }
        }
    }
}
