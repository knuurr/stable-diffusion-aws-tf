variable "aws_region" {
  description = "The AWS region in which to deploy resources."
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "The AWS profile to use for deployment"
  default     = "default"
}

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

variable "ssh_public_key_path" {
  description = "The path to the SSH public key file."
  default     = "~/.ssh/id_aws-sd.pub"
}

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
