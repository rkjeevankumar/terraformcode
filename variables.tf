variable "project" {
    type = string
    description = "Google Cloud Platform Project ID"
    default = "model-azimuth-365511"
}

variable "region" {
    type = string
    description = "Infrastructure Region"
    default = "europe-west3"
}

variable "project_name" {
    type = string
    description = "Project Name"
    default = "My First Project"
}

variable "zone" {
    type = string
    description = "Zone"
    default = "europe-west3-c"
}

variable "name" {
    type = string
    description = "The base name of resources"
    default = "apache-app2"
}

variable "deploy_version" {
    type = string
    description = "Deployment Version"
        default = "2"
}

variable "image" {
    type = string
    description = "VM Image for Instance Template"
    default = "debian-cloud/debian-11"
}

variable "tags" {
    type = list
    description = "Network Tags for resources"
    default = [ "apache-app" ]
}

variable "machine_type" {
    type = string
    description = "VM Size"
    default = "e2-medium"
}

variable "minimum_vm_size" {
    type = number
    description = "Minimum VM size in Instance Group"
    default = 2
}