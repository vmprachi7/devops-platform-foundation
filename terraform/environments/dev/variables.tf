variable "resource_group_name" { default = "devops-platform-rg" }
variable "location" { default = "centralindia" }
variable "cluster_name" { default = "devops-platform-aks" }
variable "acr_name" { default = "devopsplatformacr" }
variable "tags" {
  default = {
    project    = "devops-platform"
    owner      = "prachi"
    managed_by = "terraform"
  }
}