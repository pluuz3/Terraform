# Usage : terraform validate|apply|destroy

# ami_id 	 = ami-097834fcb3081f51a
# key_pair = Access_key_userName
# ami_name = azmlinux
# Create AMZ Linux Instant with Terraform Template
# ssh : ssh -i 'path/yourpemkey.pem' ec2-user@machineName.us-east-2.compute.amazonaws.com
#
# Layout :
#   1) Setting up AWS provider
#   2) Setting up VPC
#   3) Setting up inputs
#   4) Setting up subnets
#   5) Setting up security groups
#   6) Setting up EC2 instance
#   7) Attaching an elastic IP to EC2 instance
#   8) Setting up an internet gateway
#   9) Setting up route tables
#
# amz linux ami 2018  : ami-097834fcb3081f51a
# redhat Enterprise 8 : ami-0a54aef4ef3b5f881
# ubuntu 18.04 LTS    : ami-07c1207a9d40bc3bd
# Key pair name       : Access_key_userName

#   1) Setting up AWS provider											// connections.tf
provider "aws" {																		// https://terraform.io/docs/providers/aws/index.html
  access_key = "Your Access Key"         			      // developer keys
  secret_key = "Your AMZ Generated Your Secret Key Go Here"
  region     = "us-east-2"                          // Select your region for server location
}

#   2) Setting up VPC																//network.tf
resource "aws_vpc" "test-env" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "test-env"
  }
}

#   3) Setting up inputs														//variables.tf
variable "ami_name" {}
variable "ami_id" {}
variable "ami_key_pair_name" {}

#   4) Setting up subnets														//subnets.tf
resource "aws_subnet" "subnet-uno" {
  cidr_block = cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)
#  cidr_block = "${cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)}"
#  vpc_id = "${aws_vpc.test-env.id}"
  vpc_id = aws_vpc.test-env.id
  availability_zone = "us-east-2a"
}

#   5) Setting up security groups										//security.tf
resource "aws_security_group" "ingress-all-test" {
	name = "allow-all-sg"
#	vpc_id = "${aws_vpc.test-env.id}"
	vpc_id = aws_vpc.test-env.id
	ingress {
    cidr_blocks = ["0.0.0.0/0"]
		from_port = 22
    to_port = 22
    protocol = "tcp"
  }																									// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 	}
}

#   6) Setting up EC2 instance										//servers.tf
resource "aws_instance" "test-ec2-instance" {
  ami = var.ami_id
  instance_type = "t2.micro"
  key_name = var.ami_key_pair_name
  security_groups = ["${aws_security_group.ingress-all-test.id}"]
	tags = {
    Name = "${var.ami_name}"
  }
	subnet_id = "${aws_subnet.subnet-uno.id}"
}

#   7) Attaching an elastic IP to EC2 instance			//elastic_ip.tf
resource "aws_eip" "ip-test-env" {
  instance = "${aws_instance.test-ec2-instance.id}"
  vpc      = true
}

#   8) Setting up an internet gateway								//gateways.tf
resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.test-env.id}"
	tags = {
    Name = "test-env-gw"
  }
}

#   9) Setting up route tables											//subnets.tf
resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.test-env.id}"
	route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }
	tags = {
    Name = "test-env-route-table"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.subnet-uno.id}"
	route_table_id = "${aws_route_table.route-table-test-env.id}"
}

# https://www.terraform.io/docs/commands/output.html
output "IP" {
	value="${aws_instance.test-ec2-instance.public_ip}"
}
output "State" {
	value="${aws_instance.test-ec2-instance.instance_state}"
}
output "lb_address" {
  value = "${aws_instance.test-ec2-instance.public_dns}"
}

