terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

resource "kubernetes_namespace" "broker" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_persistent_volume" "kafkavol" {
  metadata {
    name = "kafka-volume"
  }
  spec {
    storage_class_name = "manual"
    capacity = { storage = "2Gi" }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/opt/kubernetes_volume"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "kafkapvc" {
  metadata {
    name = "kafka-volume-claim"
    namespace = kubernetes_namespace.broker.metadata[0].name
  }
  spec {
    storage_class_name = "manual"
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = { storage = "1Gi" }
    }
    volume_name = kubernetes_persistent_volume.kafkavol.metadata[0].name
  }
}

resource "kubernetes_service" "zookeeper-primary" {
  metadata {
    name      = "zookeeper-primary"
    namespace = kubernetes_namespace.broker.metadata[0].name
  }
  spec {
    type = "NodePort"
    port {
      name        = "zookeeper-primary"
      port        = 2182
      target_port = 2182
      node_port = 30000
    }
    port {
      name        = "zookeeper-internal"
      port        = 2181
      target_port = 2181
      node_port = 30001
    }
    selector = { app = "zookeeper-primary" }
  }
}

resource "kubernetes_deployment" "zookeeper-primary" {
  metadata {
    name      = "zookeeper-primary"
    namespace = kubernetes_namespace.broker.metadata[0].name
    labels    = { app = "zookeeper-primary" }
  }
  spec {
    replicas = var.zookeeper_repicas
    template {
      metadata {
        labels = { app = "zookeeper-primary" }
      }
      spec {
        container {
          name = "zookeeper-primary"
          image = "bitnami/zookeeper:latest"
          env {
            name = "ALLOW_PLAINTEXT_LISTENER"
            value = "yes"
          }
          env {
            name = "KAFKA_CFG_ZOOKEEPER_CONNECT"
            value = "zookeeper-primary:2181"
          }
          env {
            name = "ALLOW_ANONYMOUS_LOGIN"
            value = "yes"
          }
        }
        volume {
          name = "kafka-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.kafkapvc.metadata[0].name
          }
        }
      }
    } 
    selector {
      match_labels = { app = "zookeeper-primary"}
    }
  }
}

resource "kubernetes_service" "kafka-primary" {
  metadata {
    name      = "kafka-primary"
    namespace = kubernetes_namespace.broker.metadata[0].name
  }
  spec {
    type = "NodePort"
    port {
      name        = "kafka-internal"
      port        = 9092
      target_port = 9092
      node_port = 30002
    }
    port {
      name        = "kafka-external"
      port        = 9093
      target_port = 9093
      node_port = 30003
    }
    selector = { app = "kafka-primary" }
  }
}

resource "kubernetes_deployment" "kafka-primary" {
  metadata {
    name      = "kafka-primary"
    namespace = kubernetes_namespace.broker.metadata[0].name
    labels    = { app = "kafka-primary" }
  }
  spec {
    replicas = var.kafka_repicas
    template {
      metadata {
        labels = {app = "kafka-primary"}
      }
      spec {
        container {
          name = "kafka-primary"
          image = "bitnami/kafka:latest"
          env {
            name = "KAFKA_BROKER_ID"
            value = "1"
          }
          env {
            name = "KAFKA_CFG_ZOOKEEPER_CONNECT"
            value = "zookeeper-primary:2181"
          }
          env {
            name = "ALLOW_PLAINTEXT_LISTENER"
            value = "yes"
          }
          env {
            name = "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "CLIENT:PLAINTEXT,EXTERNAL:PLAINTEXT"
          }
          env {
            name = "KAFKA_CFG_LISTENERS"
            value = "CLIENT://:9092,EXTERNAL://:9093"
          }
          env {
            name = "KAFKA_CFG_ADVERTISED_LISTENERS"
            value = "CLIENT://kafka-primary:9092,EXTERNAL://localhost:9093"
          }
          env {
            name = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "CLIENT"
          }
          resources {
            requests = {  memory = "1Gi" }
          }
        }
        volume {
          name = "kafka-persistent-storage"
          persistent_volume_claim {
            read_only = "false"
            claim_name = kubernetes_persistent_volume_claim.kafkapvc.metadata[0].name
          }
        }
      }
    }
    selector {
      match_labels = { app = "kafka-primary" }
    }
  }
}

resource "kubernetes_service" "schema-reg" {
  metadata {
    name = "schema-registry"
    namespace = kubernetes_namespace.broker.metadata[0].name
  }
  spec {
    type = "NodePort"
    port {
      name = "schema-reistry"
      port = 8081
      target_port = 8081
      node_port = 30020
    }
    selector = {
      app = "schema-registry-primary"
    }
  }
}

resource "kubernetes_deployment" "schema-registry" {
  metadata {
    name = "schema-registry-primary"
    namespace = kubernetes_namespace.broker.metadata[0].name
    labels = { app = "schema-registry-primary" }
  }
  spec {
    replicas = 1
    template {
      metadata {
        labels = { app = "schema-registry-primary" }
      }
      spec {
        container {
          name = "schema-registry-primary"
          image = "confluentinc/cp-schema-registry"
          env {
            name = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
            value = "PLAINTEXT://kafka-primary:9092"
          }
          env {
            name = "SCHEMA_REGISTRY_HOST_NAME"
            value = "schema-registry-primary"
          }
          env {
            name = "SCHEMA_REGISTRY_LISTENERS"
            value = "http://0.0.0.0:8081"
          }
        }
      }
    }
    selector {
      match_labels = {
        app = "schema-registry-primary"
      }
    }
  }

}