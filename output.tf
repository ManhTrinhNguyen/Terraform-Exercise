output "ami_id" {
  value = data.aws_ami.amazon-linux-image.id
}

output "ec2_public_ip_1" {
  value = aws_instance.myapp-1.public_ip
}

output "ec2_public_ip_2" {
  value = aws_instance.myapp-2.public_ip
}