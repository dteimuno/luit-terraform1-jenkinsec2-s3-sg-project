variable "vpc_id" {
  type    = string
  default = "<your-default-vpc-id>"
}

variable "cidr_block" {
  type    = string
  default = "<your-default-vpc-ipv4-cidr>"
}

variable "my_pc_ip" {
  type    = string
  default = "<your-local-machine-ip-address"
}

variable "access_from_anywhere_cidr" {
  type    = string
  default = "0.0.0.0/0"

}

variable "ubuntu-us-east-1-ami" {
  type    = string
  default = "ami-04b4f1a9cf54c11d0"

}

variable "keypair_name" {
  type    = string
  default = "<key-pair-name"

}

variable "instance_size" {
  type    = string
  default = "t2.micro"

}

variable "security_group_name" {
  type    = string
  default = "luit-sg"

}

variable "default_aws_region" {
  type    = string
  default = "us-east-1"

}

variable "bucket_name" {
  default = "dtmluitbucket"
}
