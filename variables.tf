variable "aws_region" {
  description = "AWS region to use (e.g. `eu-central-1`)"
  type = string
  default = "eu-central-1"
}

variable "aws_profile" {
}

variable "project_name" {
}

variable "dev_key_pair_name" {
  description = "My existing SSH Key pair filename"
  default     = "id_rsa"
  type        = string
}

variable "dev_instance_type" {
  description = "instance type of EC2 dev instance"
  default     = "t3.micro"
  type        = string
}

variable "vpc_cidr" {
  default = "10.23.0.0/16"
}


