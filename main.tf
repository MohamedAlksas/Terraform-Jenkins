provider "aws" {
  profile = "Terraform_dev"
  region  = "us-east-1"
}

resource "aws_vpc" "jenkins_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id

}

resource "aws_route_table" "terraform_route_table" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }

  tags = {
    Name = "terraform_route_table"
  }
}

resource "aws_subnet" "terraform_subnet" {
  vpc_id                  = aws_vpc.jenkins_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform_subnet"
  }
}

resource "aws_route_table_association" "terraform_route_table_association" {
  subnet_id      = aws_subnet.terraform_subnet.id
  route_table_id = aws_route_table.terraform_route_table.id
}

resource "aws_security_group" "terraform_sg" {
  name        = "terraform_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "terraform_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terraform_key_pair_v2" {
  key_name   = "terraform_key_pair_v2"
  public_key = tls_private_key.terraform_key.public_key_openssh
}


resource "aws_instance" "terraform_instance" {
  ami                    = "ami-0b6d9d3d33ba97d99"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.terraform_subnet.id
  vpc_security_group_ids = [aws_security_group.terraform_sg.id]
  key_name               = aws_key_pair.terraform_key_pair_v2.key_name
  user_data              = replace(file("${path.module}/install.sh"), "\r\n", "\n")

  tags = {
    Name = "terraform_instance"
  }
}

resource "aws_eip" "terraform_eip" {
  instance = aws_instance.terraform_instance.id
  domain   = "vpc"
}


output "instance_public_ip" {
  value = aws_eip.terraform_eip.public_ip
}
