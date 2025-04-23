- [Create Git Repository for local Terraform Project](#Create-Git-Repository-for-local-Terraform-Project)

- [Install Terraform](#Install-Terraform)

- [Basic Terraform Structure](#Basic Terraform Structure)

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








