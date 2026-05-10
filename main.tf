terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

provider "openstack" {
  user_name   = "PCU-LPGJL2D"
  password    = var.os_password  # Jamais en clair !
  tenant_name = "PCP-LPGJL2D"
  auth_url    = "https://api.pub1.infomaniak.cloud/identity/v3"
  region      = "dc3-a"         
}

