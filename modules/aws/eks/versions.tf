terraform {
  required_providers {
    aws        = "= 5.100.0"
    local      = "= 2.5.3"
    null       = "= 3.2.4"
    kubernetes = "= 2.37.1"
    helm       = "= 2.17.0"
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.19.0"
    }
  }
}
