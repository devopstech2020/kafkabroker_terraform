
variable "kubeconfig" {
    type = string
    default = "~/.kube/config"
}

variable "namespace" {
    type = string
    default = "brokers"
}

variable "zookeeper_repicas" {
    type = number
    default = 3
}

variable "kafka_repicas" {
    type = number
    default = 3
}
    
