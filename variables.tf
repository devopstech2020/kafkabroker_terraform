
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
    default = 2
}

variable "kafka_repicas" {
    type = number
    default = 2
}
    
