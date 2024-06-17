pipeline {
    agent any
    environment {
        APP_VERSION = '1.0'
        DOCKER_IMAGE = 'helloworld-nodejs'
        DOCKER_IMAGE_TAGGED = '891376988072.dkr.ecr.eu-west-2.amazonaws.com/helloworld-nodejs'
        KUBE_CONFIG = '~/.kube/config'
    }
    stages {
        stage('Build') {
            steps {
                script {
                    sh 'docker build -t $DOCKER_IMAGE:$APP_VERSION .'
                    sh 'docker tag $DOCKER_IMAGE:$APP_VERSION $DOCKER_IMAGE_TAGGED:$APP_VERSION'
                }
            }
        }
        stage('Test') {
            steps {
                sh 'docker run -d -p 3000:3000 --name test-container $DOCKER_IMAGE_TAGGED:$APP_VERSION'
                sh 'sleep 10'
                sh 'curl localhost:3000'
                sh 'docker stop test-container'
                sh 'docker rm test-container'
            }
        }
        stage('Push') {
            steps {
                script {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fe277f34-c214-41e7-9ea6-b120bc80e1dc', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                        sh 'aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $DOCKER_IMAGE_TAGGED:$APP_VERSION'
                        sh 'docker push $DOCKER_IMAGE_TAGGED:$APP_VERSION'
                    }
                }
            }
        }
        stage('Initialize Infrastructure') {
            steps {
                script {
                    dir('./terraform') {
                        sh 'terraform init'
                    }
                }
            }
        }
        stage('Apply Infrastructure') {
            steps {
                script {
                    dir('./terraform') {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fe277f34-c214-41e7-9ea6-b120bc80e1dc', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                            sh 'terraform apply -auto-approve'
                        }
                    }
                }
            }
        }
        stage('Deploy to EKS') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'kubeconfig-for-eks', variable: 'KUBECONFIG'), 
                                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fe277f34-c214-41e7-9ea6-b120bc80e1dc', 
                                    accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                        sh 'export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID'
                        sh 'export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY'
                        sh 'export AWS_DEFAULT_REGION=eu-west-2'
                        sh 'kubectl apply -f ./k8s/deployment.yaml --validate=false'
                        sh 'kubectl apply -f ./k8s/service.yaml --validate=false'
                    }
                }
            }
        }
    }
    post {
        success {
            echo 'Image built and pushed successfully'
        }
        failure {
            echo 'Build or push failed'
        }
    }
}
