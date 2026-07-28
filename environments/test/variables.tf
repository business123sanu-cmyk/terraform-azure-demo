variable "subscription_id" {}

variable "location" {
  default = "Central India"
}

variable "admin_username" {}

variable "admin_password" {
  sensitive = true
}
