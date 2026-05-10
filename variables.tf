variable "os_password" {
  description = "Mot de passe OpenStack"
  sensitive   = true 
}

variable "student_count" {
  default = 5
}

variable "class_name" {
  default = "E2"
}

