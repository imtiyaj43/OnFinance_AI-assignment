variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for instances"
  type        = string
  default     = "key-name"
}

variable "db_name" {
  description = "Database name for MySQL"
  default     = "onfinancedb"
}

variable "db_username" {
  description = "Username for MySQL"
  default     = "admin"
}

variable "db_password" {
  description = "Password for MySQL"
  default     = "OnFinance123!" # Change this for real projects
}
