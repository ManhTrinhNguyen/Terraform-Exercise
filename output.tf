output "ami_id" {
  value = data.aws_ami.amazon-linux-image.id
}

output "ec2_public_ip" {
  value = aws_instance.myapp.public_ip
}