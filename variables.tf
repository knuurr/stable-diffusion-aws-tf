# General settings
variable "aws_region" {
  description = "The AWS region in which to deploy resources."
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "The AWS profile to use for deployment"
  default     = "default"
}

# Spot price
variable "spot_price" {
  description = "The maximum price you are willing to pay for a spot instance."
  default     = "0.30"
}

variable "volume_size" {
  description = "The size of the EBS volume in GB."
  default     = 50
}

variable "user_data_filename" {
  description = "The name of the user data file for the EC2 instance."
  default     = "setup.sh"
}

variable "ssh_key_tag_name" {
  description = "The name of the tag for resource."
  default     = "stable-diffusion-aws-tf"
}

variable "use_ssh_key_from_file" {
  type        = bool
  default     = true
  description = "Set to true to use an existing SSH key file, false to generate with tls_private_key"
}

variable "ssh_public_key_path" {
  description = "The path to the SSH public key file. Does nothing if 'use_ssh_key_from_file' is set to false."
  type        = string
  default     = "~/.ssh/id_aws-sd.pub"
}

# GUI/setup settings
variable "install_automatic1111" {
  description = "Tag value for INSTALL_AUTOMATIC1111."
  default     = "false"
}

variable "install_invokeai" {
  description = "Tag value for INSTALL_INVOKEAI."
  default     = "true"
}

variable "gui_to_start" {
  description = "Tag value for GUI_TO_START. Use 'invokeai' or 'automatic1111'"
  default     = "invokeai"
}
