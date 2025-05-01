- [Create Git Repository for local Terraform Project](#Create-Git-Repository-for-local-Terraform-Project)

- [Install Terraform](#Install-Terraform)

- [Basic Terraform Structure](#Basic-Terraform-Structure)

  - [Configure Terraform AWS Proivder](#Configure-Terraform-AWS-Proivder) 

- [Automate AWS Infrastructure](#Automate-AWS-Infrastructure)

  - [Overview](#Overview)
 
  - [VPC and Subnet](#VPC-and-Subnet)
 
  - [Route Table And Internet Gateway](#Route-Table-And-Internet-Gateway)
 
  - [Create new Route Table](#Create-new-Route-Table)
 
  - [Create Internet Gateway](#Create-Internet-Gateway)
 
  - [Subnet Association with Route Table](#Subnet-Association-with-Route-Table)
 
  - [Security Group](#Security-Group)
 
  - [Amazon Machine Image for EC2](#Amazon-Machine-Image-for-EC2)
 
  - [Create EC2 Instance](#Create-EC2-Instance)
 
  - [Automate create SSH key Pair](#Automate-create-SSH-key-Pair)
 
  - [Run entrypoint script to start Docker container](#Run-entrypoint-script-to-start-Docker-container)
 
  - [Extract to shell script](#Extract-to-shell-script)
 
- [Modules](#Modules)

  - [Modularize-my-project](#Modularize-my-project)
 
  - [Create Module](#Create-Module)
 
  - [Use the Module](#Use-the-Module)
 
  - [Module Output](#Module-Output)
 
  - [Create webserver Module](#Create-webserver-Module)
 
- [Provison EKS](#Provison-EKS)

  - [Steps to Provision EKS](#Steps-to-Provision-EKS)
 
  - [Create VPC](#Create-VPC)
 
  - [Create EKS Cluster and Worker Nodes](#Create-EKS-Cluster-and-Worker-Nodes)

  
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

## Install Terraform 

Docs to install Terraform (https://developer.hashicorp.com/terraform/downloads)

For Mac : 

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

## Basic Terraform Structure 

<img width="600" alt="Screenshot 2025-04-23 at 11 58 49" src="https://github.com/user-attachments/assets/ba769f7c-88c7-4326-905c-4e8380194540" />

#### Configure Terraform AWS Proivder 

In `providers.tf`

```
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.95.0"
    }
  }
}

provider "aws" { 
  region = "us-west-1"
}
```

I can add as many as Provider I needed 

Provider need my AWS Credentials in order to connect to AWS . I could have put my credentials in `prodiver "aws"` but I don't need to . Terraform will go into my ENV `~/.aws` And will take my Credetials from there . For security best practice never expose Credentials on the file 


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

To create VPC and Subnet in AWS I need `resources "aws_vpc"` and  `resources "aws_subnet"`

To create VPC, I need to define `cidr_block` like this : 

```
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tag = {
    Name: "any-name"
  }
}
```

I can extract value to `variables.tf` file and give value to it in `terraform.tfvars` .

```
main.tf

resource "aws_vpc" "my-vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

----

variables.tf

variable "cidr_block" {}
variable "env_prefix" {}

----

terraform.tfvars

cidr_block = "10.0.0.0/16"
env_prefix = "dev"
```

To create Subnet I will define like this :

 - To get VPC ID `aws_vpc.<vpc-name>.id`

```
main.tf

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.my-vpc.id # 
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}

---

variables.tf

variable "subnet_cidr_block" {}
variable "availability_zone" {}

---

terraform.tfvars

subnet_cidr_block = "10.0.10.0/24"
availability_zone = "us-west-1a"
```

After I have configured VPC and Subnet I can use `terraform apply --auto-approve` to provision it 

#### Route Table And Internet Gateway

**Route table** was generated by AWS for my newly VPC .  

Route table is Virtual Router in VPC . Route Table is just a set of rules that tell my Network where to send traffic 

 - Route table decide where to send network to within a VPC

 - When I click into Route Table in AWS UI . I see `Target : Local` and `Destination: 10.0.0.0/16` mean only route traffic inside my VPC with a range `10.0.0.0/16` .

 - !!! Important NOTE : Route table doesn't care about specific IP address like `10.0.1.15`. It work with CIDR Block, it based on where the destination IP falls, it decides which target (Gateway, endppint, NAT, etc..) to use

**Internet Gateway Target**: This mean this Route Table acutally handles or will handle all the traffic coming from the Internet and leaving the Internet

 - Basically I need the Internet Gateway Target in my Custom VPC so I can connect my VPC to the Internet

#### Create new Route Table

I will create a new Route Table with : 

 - Local Target : Connect within VPC

 - Internet Gateway: Connect to the Internet

 - By default the entry for the VPC internal routing is configured automatically . So I just need to create the Internet Gateway route

To create a Route Table `resource "aws_route_table" "myapp-route-table" {}`

 - I need to give `vpc_id` where is Route Table will create from (required)

 - Then I will put Route into my Route table (Internet Gateway, NAT, or Local) . Local is automatically created

 - My route table will look like this :

  ```
  resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

    route {
      cidr_block = "0.0.0.0/0" ## Destination . Any IP address can access to my VPC 
      gateway_id = aws_internet_gateway.myapp-igw.id ## This is a Internet Gateway for my Route Table 
    }

    tags = {
      Name = "${var.env_prefix}-rtb"
    }
  }
  ```

But I don't have IGW yet . Now I will go and create my IGW 

#### Create Internet Gateway

To create Internet Gateway : `resource "aws_internet_gateway" "myapp-igw" {}`

 - I need to give `vpc_id` where is IGW will create from (required)

  ```
  resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
  
    tags = {
      Name = "${var.env_prefix}-rtb"
    }
  }
  ```

**Recap**: I have configured VPC and Subnet inside VPC . I am connecting VPC to Internet Gateway and then I am configureing a new Route Table that I am creating in the VPC to route all the Traffic to and from using the Internet Gateway

!!! Best Practice : Create new components, instead of using default ones

#### Subnet Association with Route Table

I have created a Route Table inside my VPC. However I need to associate Subnet with a Route Table so that Traffic within a Subnet also can handle by Route Table 

By default when I do not associate subnets to a route table they are automatically assigned or associated to the main route table in that VPC where the Subnet is running

To Associate Subnet : `resource "aws_route_table_association" "a-rtb-subnet" {}`

```
resource "aws_route_table_association" "a-rtb-subnet" {
  route_table_id = aws_route_table.myapp-route-table.id
  subnet_id = aws_subnet.myapp-subnet.id
}
```

**Best Practice** : is to create a new Route table instead of using a default one 

**Typical Best Practice Setup:**

 - Create a Public Route Table → route to Internet Gateway → associate with public subnets.

 - Create a Private Route Table → route to NAT Gateway → associate with private subnets.

 - Create an Internal Route Table → no external route → for database/backend subnets.

#### Security Group

When I deploy my virtual machine in the subnet, I want to be able to SSH into it at port 22 . As well as I want to accessing nginx web server that I deploy as a container, through the web browser so I want to open port 8080 so that I can access from the web browser

First I need `vpc_id`, so I have to associate the Security Group with the VPC so that Server inside that VPC can be associated with the Security Group and VPC ID 

Generally I have 2 type of rules: 

 - Traffic coming in inside the VPC called `Ingress` . For example When I SSH into EC2 or Access from the browser

   - The resone we have 2 Ports `from_port` and `to_port` It is bcs I can acutally configure a Range . For example If I want to open Port from 0 to 1000 I can do `from_port = 0` && and `to_port = 1000`

   - `cidr_blocks` : Sources who is allowed or which IP addresses are allowed to access to the VPC

   - For SSH accessing the server on SSH should be secure and not everyone allow to do it

   - If my IP address is dynamic (change alot) . I can configure it as a variable and access it or reference it from the variable value instead of hard coding . So I don't have to check the terraform.tfvars into the repository bcs this is the local variables file that I ignored . Bcs everyone can have their own copy of variable file and set their own IP address

 - Traffic outgoing call `egress` . The arrtribute for these are the same

   - Example of Traffic leaving the VPC is :

     - Installation : When I install Docker or some other tools on my Server these binaries need to be fetched from the Internet

     - Fetch Image From Docker Hub or somewhere else

To create SG : `resource "aws_security_group" "myapp-sg" {}`

```
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.myapp-vpc.id 
}
```

To create Ingress rule : `resource "aws_vpc_security_group_ingress_rule" {}`

```
resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-ssh" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = var.my_ip
  from_port = 22
  ip_protocol = "TCP"
  to_port = 22
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-8080" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8080
  ip_protocol = "TCP"
  to_port = 8080
}
```

To create Egress rule : `resource "aws_vpc_security_group_egress_rule" "myapp-sg-egress" {}`

```
resource "aws_vpc_security_group_egress_rule" "myapp-sg-egress" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}
```

#### Amazon Machine Image for EC2 

**Review** : I have a VPC that has a Subnet inside . Connect VPC to Internet using Internet Gate Way and configure it in the Route Table . I also have create Security Group that open Port 22, 8080

To get AWS Image for EC2 I use `data "aws_ami" "my_ami" {}`

 - `ami` : Is a Operating System Image . Values of this is a ID of the image `ami-065ab11fb3d0323d`

 - So Instead hard code `ami id` I will use `data` to fetch the Image ID

 - To get Owners got to EC2 -> Image AMIs -> paste the ami id image that I want to get owner from. I will see the owner on the tap

 - Then I have a `filter` . `filter` in data let me define the criteria for this query . Give me the most recent Image that are owned by Amazon that have the name that start with amzn2-ami-kernel (Or can be anything, any OS I like to filter) . In `filter {}` I have `name` attr that referencing which key I wants to filter on, and `values` that is a list

 - `Output` the aws_ami value to test my value is correct `output "aws_ami_id" { value = data.aws_ami.latest-amazon-linux-image }` . Then I will see terraform plan to see the output object . However with output is how I can actually validate what results I can getting with this data execution . After this I can get the AMI-ID and put it in ami

 - My `data "aws_ami" "my_ami" {}` look like this

  ```
  main.tf

  data "aws_ami" "amazon-linux-image" {

  owners = ["amazon"]
  most_recent = true 

  filter {
    name = "name"
    values =  ["al2023-ami-*-x86_64"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
    }
  }

  ---

  output.tf

  output "ami_id" {
    value = data.aws_ami.amazon-linux-image.id
  }
  ```

#### Create EC2 Instance

Now I have `aws_ami` image ID I can create EC2 Instance from that 

I can use `resource "aws_instance" ""` to create instance 

`ami` : Is my Instance image 

`instance_type`: I can choose `instance_type` like how much Resources I want 

Other Attribute is Optional like subnet id and security group id etc ... If I do not specify them explicitly, then the EC2 instance that we define here will acutally launched in a default VPC in one of the AZ in that Region in one of the Subnet . However I have create my own VPC and this EC2 end up in my VPC and be assign the Security Group that I created in my VPC .

To define specific Subnet : `subnet_id = aws_subnet.myapp-subnet-1.id`

To define specific SG : `vpc_security_group_ids = [aws_security_group.myapp-sg.id]`  To start the instance in 

`associate_public_ip_address = true`. I want to be able access this from the Browser and as well as SSH into it 

To define Availability Zone : `availability_zone`

I need the keys-pair (.pem file) to SSH to a server . Key pair allow me to SSH into the server by creating public private key pair or ssh key pair . AWS create Private Public Key Pair and I have the private part in this file .

 - To secure this file I will move it into my user .ssh folder : `mv ~/Downloads/server-key-pair-pem ~/.ssh/` and then restrict permission :`chmod 400 ~/.ssh/server-key-pair.pem`. This step is required bcs whenever I use a `.pem` doesn't a strict access aws will reject the SSH request to the server

My whole code will look like this : 

```
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet" {
  vpc_id     = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0" ## Destination . Any IP address can access to my VPC 
    gateway_id = aws_internet_gateway.myapp-igw.id ## This is a Internet Gateway for my Route Table 
  }

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  route_table_id = aws_route_table.myapp-route-table.id
  subnet_id = aws_subnet.myapp-subnet.id
}

resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.myapp-vpc.id 
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-ssh" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = var.my_ip
  from_port = 22
  ip_protocol = "TCP"
  to_port = 22

  tags = {
    Name = "${var.env_prefix}-ingress-ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-8080" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8080
  ip_protocol = "TCP"
  to_port = 8080

  tags = {
    Name = "${var.env_prefix}-ingress-8080"
  }
}

resource "aws_vpc_security_group_egress_rule" "myapp-sg-egress" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.env_prefix}-egress"
  }
}

data "aws_ami" "amazon-linux-image" {

  owners = ["amazon"]
  most_recent = true 

  filter {
    name = "name"
    values =  ["al2023-ami-*-x86_64"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "myapp" {
  ami = data.aws_ami.amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp-subnet.id 
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true

  key_name = "terraform-exercise"
  tags = {
    Name = "${var.env_prefix}-myapp"
  }
}
```

----

```
terraform.tfvars

cidr_block = "10.0.0.0/16"
env_prefix = "dev"
subnet_cidr_block = "10.0.10.0/24"
availability_zone = "us-west-1a"
my_ip = "157.131.152.31/32"
instance_type = "t3.micro"

variables.tf

variable "cidr_block" {}
variable "env_prefix" {}
variable "subnet_cidr_block" {}
variable "availability_zone" {}
variable "my_ip" {}
variable "instance_type" {}
```

#### Automate create SSH key Pair

I will use `resource "aws_key_pair" "ssh-key"` to generate key-pair 

`public_key` : I need a Public Key so AWS can create the Private key pair out of that Public key value that I provide

To get `public_key` : `~/.ssh/id_rsa.pub` 

To use that `public_key` in Terraform I can extract that key into a `Variable` or I can use File location

 - `puclic_key = file("~/.ssh/rsa.pub")` or I can set location as variable `public_key = file(var.my_public_key`) and then in `terraform.tfvars` I set the `public_key_location` variable `public_key_location = "~/.ssh/id_rsa.pub"`

```
main.tf

variable public_key_location {}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}
```
----

```
terraform.tfvars

public_key_location = "/Users/trinhnguyen/.ssh/id_rsa.pub"
```

#### Run entrypoint script to start Docker container

Now I have EC2 server is running and I have Networking configured . However there is nothing running on that Server yet . No Docker install, No container Deployed

I want to ssh to server, install docker, deploy container automatically . So i will create configuration for it too

With Terraform there is a way to execute commands on a server on EC2 server at the time of creation . As soon as Intances ready. I can define a set of commands that Terraform will execute on the Server . And the way to do that is using Attr `user_data`

`user_data` is like an Entry point script that get executeed on EC2 instance whenever the server is instantiated . I can provide the script using multiline string and I can define it using this syntax

My `user_data` would look like this inside `resources aws_instance`:

```
resource "aws_instance" "myapp" {
  ami = data.aws_ami.amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp-subnet.id 
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true

  key_name = "terraform-exercise"


  user_data = <<EOF
    ### Inside this block I can define the whole shell script . Just like I would write it in a normal script file, in a bash file
                #!/bin/bash
                sudo yum update -y && sudo yum install -y docker
                sudo systemctl start docker
                sudo usermod -aG docker ec2_user
                docker run -p 8080:80 nginx
                EOF

  user_data_replace_on_change = true
  tags = {
    Name = "${var.env_prefix}-myapp"
  }
}
```

 - `-y`: Stand for automatic confirmation

 - sudo systemctl start docker : Start docker

 - sudo usermod -aG docker ec2_user : Make user can execute docker command without using sudo

 - So above is a user_data command that will run everytime the instance gets launched . I just need to configure the Terraform file, so that each time I change this user data file, The Instance actually get destroyed and re-created.

 - If I check AWS_Provider docs and check for `aws_intance` I can see the `user_data` input filed has an optional flag `user_data_replace_on_change` . I want enable this flag, I want to ensure that my Instance is destroyed and recreated when I modify this user_data field . This way I know that my user data script is going to run each time on the clean, brand-new instance, which will ge me a consistent State

!!! NOTE : user_data will only executed once . However bcs I add `user_data_replace_on_change = true` now if the `user_data` script itself changes this will force the recreation of the of the instance and re-execution of the user data script . But again this is only if something in the `user_data` script itself changes. If changes everything else like tags , key_name .... In this case it not going to force the recreation of the instance

#### Extract to shell script

Of course if I have longer and configuring a lot of different stuff I can also rerference it from a file .

I will use file location `user_data = file("entry-script.sh")`

In the same location I will create a `entry-script.sh` file

## Modules 

In Terraform we have concept of modules to make configuration not monolithic . So I am basically break up part of my configuration into logical groups and package them together in folders . and this folders then represent modules

#### Modularize my project

I will create a branch for module `git checkout -b modules`

Best practice: Separate Project structure . Extract everything from main to those file

 - main.tf

 - variable.tf

 - outputs.tf

 - providers.tf

I don't have to link that file I don't have to reference the `variable.tf` and `output.tf` bcs Terraform knows that these files belong together and it kind of grabs everyting and link them together

And I also have the providers.tf files that will hold all of the providers which I have configured already . Eventhough I have only 1 here which is our AWS provider it is Best Pratice to use providers file in the same way .

#### Create Module 

Create folder call modules : `mkdir modules` 

Inside modules :

 - Create folders for the acutal modules : `mkdir webserver` - `mkdir subnet`

 - Each module will have its own `main.tf`, `output.tf`, `providers.tf`, `variables.tf`.

I will extract the whole Configuration of the networking . Grap those 3 resources (Subnet, Internet Gateway, Route table and its association with gateway). In this case I will extract those resources into `/subnet/main.tf` 

`aws_internet_gateway` reference of a resource that exist in the same module . So we don't have to replace that through a variable bcs we have that resource available in the same context

If anything don't have reference inside the same context I have to replace with `variable`

My `/subnet/main.tf` would look like:

```
resource "aws_subnet" "myapp-subnet" {
  vpc_id     = var.vpc_id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}

resource "aws_route_table" "myapp-route-table" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0" ## Destination . Any IP address can access to my VPC 
    gateway_id = aws_internet_gateway.myapp-igw.id ## This is a Internet Gateway for my Route Table 
  }

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  route_table_id = aws_route_table.myapp-route-table.id
  subnet_id = aws_subnet.myapp-subnet.id
}
```

Now I have to define all those `variables` inside that module subnet in the `/subnet/variables.tf` . So all the variable definitions must actually be in that file.

```
variable "vpc_id" {}
variable "subnet_cidr_block" {}
variable "availability_zone" {}
variable "env_prefix" {}
```

#### Use the Module

The way to use that is, in `root/main.tf` I use `module "myapp-subnet" {}` . Then I need a couple of Attribute

`source = "modules/subnet"` : Where this module actually living .

Once source is defined now We have to pass in all those `variables` that I defined in `/subnet/variable.tf`, the value to those variables need to be provided when we are refering to module

 - Previously we had all these variables already set in `root/terraform.tfvars` . Now since we use module we have to define them in the module `"myapp-subnet" {}` section .

 - I can set `subnet_cidr_block = "0.0.0.0/32"` by hard coding like this OR We can also set them as a `variables subnet_cidr_block = var.subnet_cidr_block` . If I want to reference it from `root/main.tf` in the root module we need that variable defininition also in the `variables.tf`

 - We are referencing a `variable` called `sunbet_cidr_block` that has to be define in the same module where `root/main.tf` is . And those `/root/variable.tf` then are set through the `terraform.tfvars` (Where I define value for all those variable)

 - So this is how it work . Actual Values defined in `terraform.tfvars` -> that are set as values in `root/variables.tf` -> and then passing on those values like `var.subnet_cidr_block` to the module `"myapp-subnet"` which is also grabbing those values through variable references which also have to be find in the `subnet/variables.tf`

My subnet module in root/main.tf would look like : 

```
module "myapp-subnet" {
  source = "./modules/subnet"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  env_prefix = var.env_prefix
}
```

#### Module Output

To access the resources that will be created by a module in another module

The first thing we need to do is output the subnet object . Kinda like exporting the subnet object so that it can be used by other modules the way we do that by using `output` component `/subnet/output.tf` like this:

```
output "subnet_id" {
  value = aws_subnet.myapp-subnet.id
}
```

Then to reference the `output` in `/subnet/output.tf` to `root/main.tf` I need: `module.<name-of-module>.<name-of-output-for-that-module>.id` . The code should look like this : 

```
resource "aws_instance" "myapp" {
  subnet_id = module.myapp-subnet.subnet_id
}
```

Now I can apply configuration change : 

 - `terraform init` : Basically Terraform detects that we are referring to a module called module `"my-subnet" {}` it only tries to find and initialzi that module

 - `terraform` : Acutal apply the code

#### Create webserver Module

We have the instance itself, key-pair that created for the Instance, we have the AMI query from the AWS which is also relevant for the Instance, and we have the Security Group, which also configures the Firewalls for the Instance

In `webserver/main.tf` . We need to fix the reference to all the value like `vpc_id` . We can leave all these fixed coded values if they don't change Or we can also parameterized them if we want to pass in different values .

For example: If we want to be able to decide which operating system image should be use for the Instances : `values = [var.image_name]`

`subnet_id = aws_subnet.myapp-subnet-1.id` We don't have access to a module anymore bcs this module actually define outside . So we will parameterize that as well . `subnet_id = var.subnet_id`.

Then I will move the `entry-script.sh` to webserver module

My code should look like this : 

```
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-ssh" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = var.my_ip
  from_port = 22
  ip_protocol = "TCP"
  to_port = 22

  tags = {
    Name = "${var.env_prefix}-ingress-ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-8080" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8080
  ip_protocol = "TCP"
  to_port = 8080

  tags = {
    Name = "${var.env_prefix}-ingress-8080"
  }
}

resource "aws_vpc_security_group_egress_rule" "myapp-sg-egress" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.env_prefix}-egress"
  }
}

data "aws_ami" "amazon-linux-image" {

  owners = ["amazon"]
  most_recent = true 

  filter {
    name = "name"
    values =  [var.image_name]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "myapp" {
  ami = data.aws_ami.amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true

  key_name = "terraform-exercise"


  user_data = file("${path.module}/entry-script.sh")

  user_data_replace_on_change = true
  tags = {
    Name = "${var.env_prefix}-myapp"
  }
}
```

Declare all those variables in the `/webserver/variables.tf` 

```
variable "vpc_id" {}
variable "my_ip" {}
variable "env_prefix" {}
variable "instance_type" {}
variable "availability_zone" {}
variable "subnet_id" {}
variable "image_name" {}
```

In `/root/main.tf` . We are referencing every value either using `VAR` or module or resource name which is good pratice bcs we are not hardcoding any value .

```
module "myapp-webserver" {
  source = "./modules/webserver"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_id = module.myapp-subnet.subnet_id
  my_ip = var.my_ip
  env_prefix = var.env_prefix
  availability_zone = var.availability_zone
  image_name = var.image_name
  instance_type = var.instance_type
}
```

We have to make sure that all those values are actually defined in our `terrform.tfvars`

```
cidr_block = "10.0.0.0/16"
env_prefix = "dev"
subnet_cidr_block = "10.0.10.0/24"
availability_zone = "us-west-1a"
my_ip = "157.131.152.31/32"
instance_type = "t3.micro"
image_name = "al2023-ami-*-x86_64"
```

in `/webserver/output.tf`:

```
output "ec2_puclic_ip" {
  value = aws_instance.myapp.public_ip
}
```

in `root/output.tf`:

```
output "ec2_public_ip" {
  value = module.myapp-webserver.ec2_puclic_ip
}
```

So now we have updated all of our files, so that the references to all the different modules, resources and outputs should not have any issues when we try to run Terraform commands.

Run `terraform plan` to preview

`terraform apply` : To acutal apply the code 

#### Wrap up 

We created modules . We are logically grouped similar resources that belong together into own module while still creating one of the resources outside . We also learn how to use those modules how to reference them and pass on different values that we configured inside the modules themselves . As well as we will learn how to reference the resource object inside the modules itself using this module reference and then basically just access any attribute of that object

We have all all the resources parameterzied which is the **best practice** . So all the values are set in one place in the tf vats file . If something changes we just adjust it in one place

## Provison EKS

#### Steps to Provision EKS 

I need to create (EKS), the Control Plane that Managed by AWS

Once I have Control Plane Nodes I need to connect those Worker Nodes to the Control Planes Nodes in order to have a complete cluster so that I can start deploying my application . For that I need to create VPC where is my Worker Nodes will run 

So I create cluster always in a specific region my region has multiple availability zones (2 or 3) . I end up with a highly available Control Plane which is managed by AWS which is running somewhere else, And I have the Worker Nodes that I create myself and connect to the Control Plane that we also want to be highly available so we want to deploy them into all the available AZs of our region

#### Create VPC 

VPC for EKS cluster actually needs a very specific configuration of a VPC and the subnet inside as well as route tables and so on

I will use AWS VPC modules to create VPC for EKS (https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)

In will create `touch vpc.tf` file :

```
variable "vpc_cidr_block" {}
variable "private_subnets_cidr_block" {}
variable "public_subnets_cidr_block" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  private_subnets = var.private_subnets_cidr_block
  public_subnets  = var.public_subnets_cidr_block
}
```

**Best practice**: Always use variable instead of hardcoding

**Specify the Cidr block of subnets**: Basically inside the module "vpc" the subnet resources are already define . So subnet will be created . We can decide how many subnet and which subnets and with which cidr blocks they will be created . And for EKS specifically there is actually kind of the best practice for how to configure VPC and its Subnets

**Best Practice** : Create one Private and one Public Subnet in each of the Availability Zones in the Region where I am creating my EKS . In my region there are 3 AZs so I need to create 1 Private and 1 Public key in each of those AZs so 6 in total

In `terraform.tfvars`

```
vpc_cidr_block = "10.0.0.0/16"

private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

public_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
```

I need to define that I want those subnets to be deployed in all the availability zones . So I want them to be distributed to these 3 AZs that I have in the Region and for that I have an attribute here called `azs` and I need to define a name of those AZs `azs = ["us-west-1a", "us-west-1b", "us-west-1c"]` .

 - But I want to dynamically set the Regions . By using `data` to query AWS to give me all the AZ for the region

 - I have to specify which Region I am querying the AZs from . Then it will give me AZs from the Region that is defined inside the AWS providers

```
provider "aws" {
  region = "us-west-1"
}

variable "vpc_cidr_block" {}
variable "private_subnets_cidr_block" {}
variable "public_subnets_cidr_block" {}

data "aws_availability_zones" "azs" {} # data belong to a provider so I have to specify the Provider .

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  private_subnets = var.private_subnets_cidr_block
  public_subnets  = var.public_subnets_cidr_block
  azs = data.aws_availability_zones.azs.names
}
```

Then I will enable the `enable_nat_gateway` . By default the nat gateway is enabled for the the subnets . However we are going to set it to true for transparency and Also I am going to enable single nat gateway which basically creates a shared common nat gateway for all the private Subnet so they can route their internet traffic through this shared nat Gateway

Then I want to `enable_dns_hostnames` inside our VPC . For example when EC2 instances gets created it will get assigned the Public IP address, and private IP address but it will also get assigned the public and private DNS names that resolve to this IP address

```
enable_nat_gateway = true
single_nat_gateway = true
enable_dns_hostnames = true 
```

I also want to add tags :

 - Why do I have this tags ? `"kubernetes.io/cluster/myapp-eks-cluster" = "shared"` . Basically I have used tag to lables our resources so that I know for example which environment they are belong to so we have a tag with environment prefix

 - Tags are also for referencing components from other components programmatically .
 
 - Basically in EKS Cluster when we create the Control Plane, one of the processes in the Control Plane is `Kubernetes Cloud Controller Manager`, and this `Cloud Controller Manager` actually that com from AWS is the one that Orchestrates connecting to the VPC, connecting to the Subnets, connecting with the Worker Nodes and all these configurations, it talking to the resources in our AWS Account and Creating some stuff . So Kubernetes Cloud Manager needs to know which resources in our account it should talk to, It needs to know which VPC should be used in a Cluster, Which Subnet should be use in the Cluster . Bcs We may have multiple VPC and multiple Subnets and we need to tell control Plane or AWS, use these VPCs and these subnet for this specific cluster . We may also have multiple VPCs for multiple EKS Clusters so it has to be specific label that Kubernetes Cloud Controller Manager can acutally detect and identify

 - These tag are basically there to help the Cloud Control Manager identify which VPC and subnet it should connect to , and that is why I have the Cluster Name here bcs obviously if I have multiple Cluster I can differentiate the VPCs and subnets or the lables using the cluster name

 - In public subnets all three of them, I will add another the tag called `kubernetes.io/role/elb`

 - And for Private Subnet I have `kubernetes.io/role/internalelb`

 - So public has elb which is elastic load balancer and private has internal elb . So basically when I create load balancer service in Kubernetes, Kubernetes will provision a cloud native load balancer for that service . However it will provision that cloud load balancer in the Public Subnet bcs the Load Balancer is actually an entry point to a Cluster and Load Balancer gets an external IP Address so that we can communicate to it from outside, like from browser request or from other clients . And since we have Public Subnet and Private Subnet in VPC the Public one is actually a subnet that allows communication with Internet . Private subnet closed to Internet . So If I deploy Load Balancer in Private one I can't access it bcs it blocked . So kubernetes need to know basically which one is a public subnet so that it can create and provision that load balancer in the public subnet So that the load balancer can be accessed from the Internet . And there are also internal Load Balancers in AWS which will be created for services and components inside the Private Subnets

 - So these tag are acutally for consumption by the `Kubernetes Cloud Controller Manager` and `AWS load balancer controller` that is responsible for creating load balancer for Load Balancer Service Type

 - !!! NOTE : Those tags are required

```
tags = {
  "kubernetes.io/cluster/myapp-eks-cluster" = "shared" # This will be a cluster name
}

public_subnet_tags = {
  "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  "kubernetes.io/role/elb" = 1
}

private_subnet_tags = {
  "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  "kubernetes.io/role/internal-elb" = 1
}
```

#### Create EKS Cluster and Worker Nodes

Now I have VPC already configured . I will create EKS Cluster

I will create `touch eks-cluster.tf` file 

I will use the EKS `module` . This will basically create all the resources needed in order to create cluster as well as any Worker Nodes that I configure for it and provision some of the part provision some of the part of Kubernetes (https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

First I add `cluster_name` and `cluster_version`

Then I need to set `subnet_ids` . This is a list of Subnet that I want the Worker Nodes to be started in . So I have created a VPC with 6 Subnets (3 Private and 3 Public) .

 - Private : Where I want my Workload to be scheduled .

 - Public : are for external resources like Load Balancer of AWS for external connectivity

 - I will reference private subnet for `subnets_id = module.myapp-vpc.private_subnets` . For Security reason bcs It is not exposed to Internet

Then I can set `tags` for EKS Cluster itself . I don't have to set some required text like I did in the vpc module

 - If I am running my Microservice Application in this Cluster then I can just pass in the name of my Microservice Application, just to know which Cluster is running in which Application

In addition to Subnet or the Private Subnets where workloads will run we also need to provide a VPC id . I can also reference it through module: `module.myapp-vpc.vpc_id`

Then I need to configure how I want my Worker Nodes to run or what kind of Worker Nodes I want to connect to this Cluster :

 - In this case I will use Nodegroup semi-managed by AWS `eks_managed_node_groups` . The Value of this Attribute is a map of EKS managed NodeGroup definitions .

NOTE : Also Now I have to create the Role for the Cluster and for the Node Group as well . This eks module acutally define those roles and how they should be created . So we don't have to configure them

My code will look like this  :















