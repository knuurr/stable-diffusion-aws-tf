output "instance_id" {
    description = "Stable Diffusion EC2 Instance ID"
    value = aws_instance.aws_sd_ec2.id
}

# output "public_ip" {
#     description = "Stable Diffusion EC2 Public IP"
#   value = aws_instance.example.public_ip
# }

output "spot_instance_request_id" {
    description = "Spot Instance Request ID"
    value = aws_instance.aws_sd_ec2.spot_instance_request_id
}
