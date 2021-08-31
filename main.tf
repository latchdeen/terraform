terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
    region = "us-east-1"
    access_key="AKIA3ZWVVRTAY5FLY4NL"
    secret_key="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"
}

# Main VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/18"

  tags = {
    Name = "Main VPC"
  }
}

# Public Subnet with Default Route to Internet Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Public Subnet"
  }
}

# Private Subnet with Default Route to NAT Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Private Subnet"
  }
}

# Main Internal Gateway for VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

# Elastic IP for NAT Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT Gateway EIP"
  }
}

# Main NAT Gateway for VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "Main NAT Gateway"
  }
}

# Route Table for Public Subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Association between Public Subnet and Public Route Table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Association between Private Subnet and Private Route Table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_network_interface" "nic" {
  subnet_id   = aws_subnet.private.id
#   private_ips = ["172.16.10.100"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "linuxvm" {
  ami           = "ami-0c2b8ca1dad447f8a"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.sshkey.id

  network_interface {
    network_interface_id = aws_network_interface.nic.id
    device_index         = 0
  }
} 

resource "aws_key_pair" "sshkey" {
  key_name   = "mykey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCUXZZiIYW+ED0U1qth/AB1UlbAj+KLAwbyEtCH41wDvsaAduBjqKC9AbVgP6T0bCTAu3Z2gE73wMwNjCikD3YJKJ6kOIR8p7QKtJxCfB6Pglx/1aEuObCbz7b//eDfS1R5yXNK2duhUR+3F9oW95widxdMLj7K6GtEFoBvorbxLu3+zzu2Dipi0WZ3eASxBArwSb/7rY6OvdiWcDPaUgPOCE62vPfvsnZos5XphPWTdWtO1ouHF+9PA1RGv4wx3AqjRXnZJ/VZ4WupM0u+VbehVGYYGImshyldrBJkKeFScBtCZUGdLiM7OdtsGkJwv3N83pQ26OhhaGppD2nIAoKT"
}
