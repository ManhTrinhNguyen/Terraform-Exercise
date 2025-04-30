output "ec2_puclic_ip" {
  value = aws_instance.myapp.public_ip
}