- [Create Git Repository for local Terraform Project](#Create-Git-Repository-for-local-Terraform-Project)

- [Automate AWS Infrastructure](#Automate-AWS-Infrastructure)

  - [Overview](#Overview)
 
  - [VPC and Subnet](#VPC-and-Subnet)
  
# Terraform-Exercise

## Create Git Repository for local Terraform Project

Initialize empty repo : git init

Connect to remote folder : git remote add origin <git-repo-url> . This is will point to the remote project I have create in Github

git status (check current status of git) : It tell me I have to check in all the code

`.gitignore`:

 - Ignore .terraform/* folder . Doesn't have to part of the code bcs when I do terraform init it will be downloaded on my computer locally

 - Ignore *.tfstate, *.tfstate.* bcs Terraform is a generated file that gets update everytime I do terraform apply.

 - Ignore *.tfvars the reason is Terraform variables are a way to give users of terraform a way to set Parameter for the configurations file this parameters will be different base on the Environment . Also Terraform file may acutally contain some sensitive data

Basiccally I have main.tf, providers.tf, .terraform.lock.hcl

 - terraform.lock.hcl file should be check in bcs this is a list of Proivders that I have installed locally with specific version

## Automate AWS Infrastructure

#### Overview 

I will Deploy EC2 Instances on AWS and I will run a simple Docker Container on it 

However before I create that Instance I will Provision AWS Infrastructure for it

To Provision AWS Infrastructure :

 - I need create custom VPC

 - Inside VPC I will create Subnet in one of AZs, I can create multiple Subnet in each AZ

 - Connect this VPC to Internet using Internet Gateway on AWS . Allow traffic to and from VPC with Internet

 - And then In this VPC I will deploy an EC2 Instance

 - Deploy Nginx Docker container

 - Create SG (Firewall) in order to access the nginx server running on the EC2

 - Also I want to SSH to my Server. Open port for that SSH as well

**Terraform Best Pratice**: That I want to create the whole Infrastructure from sratch, I want to deploy everything that I need. And when I don't need it anymore later I can just remove it by using `terraform destroy` without touching the defaults created by AWS . 

#### VPC and Subnet 




