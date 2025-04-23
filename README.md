- [Create Git Repository for local Terraform Project](#Create-Git-Repository-for-local-Terraform-Project)
  
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
