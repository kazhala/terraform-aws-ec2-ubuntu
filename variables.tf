variable "region" {
  description = "Region to deploy the infrastructure."
  type        = string
  default     = "ap-southeast-2"
}

variable "access_key" {
  description = "AWS IAM User access key."
  type        = string
}

variable "secret_key" {
  description = "AWS IAM User secret key "
  type        = string
}

variable "tags" {
  description = "Additional resource tags to apply to applicable resources. Format: {\"key\" = \"value\"}."
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Default name for the resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy the EC2 instance."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet to deploy the EC2 instance. Required if vpc_id is set."
  type        = string
  default     = null
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "ip_addresses" {
  description = "Office and Home IP addresses."
  type        = list(string)
  default     = []
}

variable "email" {
  description = "Email address to receive notificaiton."
  type        = string
  default     = null
}

variable "time_zone" {
  description = "Current timezone. Allowed values: AEDT | AEST."
  type        = string
  default     = "AEST"

  validation {
    condition     = var.time_zone == "AEDT" || var.time_zone == "AEST"
    error_message = "Allowed values: AEDT | AEST."
  }
}

variable "ami" {
  description = "The ID of the AMI to launch the EC2 instance."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "The Instance Type to use."
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Volume size for the EC2 instance."
  type        = number
  default     = 30
}

variable "instance_password" {
  description = "The password of the instance."
  type        = string
}
