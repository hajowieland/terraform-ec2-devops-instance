variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}

variable "aws_profile" {}

variable "project_name" {}

variable "dev_key_pair_name" {
  description = "My existing SSH Key pair filename"
  default     = "id_rsa"
  type        = "string"
}

variable "dev_instance_type" {
  description = "instance type of EC2 dev instance"
  default     = "t3.micro"
  type        = "string"
}
