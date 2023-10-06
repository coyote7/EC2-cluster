variable "server_port" {
  description = "network ports for access"
  type        = number
  default     = 8080
}
variable "protocol" {
  description = "defines the value for the  network protocol"
  type        = string
  default     = "tcp"
}
variable "all_ips" {
  description = "defines the ip  address set allowed to access the instance "
  default     = ["0.0.0.0/0"]
}
