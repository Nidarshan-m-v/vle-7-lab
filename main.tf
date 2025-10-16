variable "aws_region" {
  description = "AWS region to use"
  type        = string
  default     = "ap-south-1"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_key_pair" "vle7_kp" {
  key_name   = "vle7-key"
  public_key = file("~/.ssh/vle7_key.pub")
}

resource "aws_vpc" "vle7_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vle7-vpc" }
}

resource "aws_subnet" "vle7_subnet" {
  vpc_id                  = aws_vpc.vle7_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "vle7-subnet" }
}

resource "aws_internet_gateway" "vle7_igw" {
  vpc_id = aws_vpc.vle7_vpc.id
  tags = { Name = "vle7-igw" }
}

resource "aws_route_table" "vle7_rt" {
  vpc_id = aws_vpc.vle7_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vle7_igw.id
  }
  tags = { Name = "vle7-rt" }
}

resource "aws_route_table_association" "vle7_rta" {
  subnet_id      = aws_subnet.vle7_subnet.id
  route_table_id = aws_route_table.vle7_rt.id
}

resource "aws_security_group" "vle7_sg" {
  name        = "vle7-jenkins-sg"
  description = "Allow SSH and Jenkins"
  vpc_id      = aws_vpc.vle7_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "vle7-sg" }
}

resource "aws_instance" "vle7_lab" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.vle7_subnet.id
  vpc_security_group_ids      = [aws_security_group.vle7_sg.id]
  key_name                    = aws_key_pair.vle7_kp.key_name
  associate_public_ip_address = true

  tags = {
    Name = "vle-7-lab"
  }
}

output "jenkins_public_ip" {
  value = aws_instance.vle7_lab.public_ip
}
