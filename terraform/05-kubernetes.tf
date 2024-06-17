resource "kubernetes_deployment" "helloworld-deployment" {
  metadata {
    name = "helloworld-app"
    labels = {
      app = "helloworld-app"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "helloworld-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "helloworld-app"
        }
      }

      spec {
        container {
          image = "891376988072.dkr.ecr.eu-west-2.amazonaws.com/helloworld-nodejs:1.0"
          name  = "helloworld"

          port {
            container_port = 3000
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "400Mi"
            }
          }
        }  
      }
    }
  }
}

resource "kubernetes_service" "helloworld-service" {
  metadata {
    name = "helloworld-service"
  }

  spec {
    selector = {
      app = "helloworld-app"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}
