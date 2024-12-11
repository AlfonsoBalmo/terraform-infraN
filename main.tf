provider "aws" {
  region = "us-east-1"  # Norte de Virginia
  alias  = "virginia"
}

provider "aws" {
  region = "us-east-2"  # Ohio
  alias  = "ohio"
}

# VPC en Virginia
resource "aws_vpc" "virginia" {
  provider = aws.virginia
  
  cidr_block                       = "172.40.1.0/24"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name = "prisma-dicio"
  }
}

# VPC en Ohio
resource "aws_vpc" "ohio" {
  provider = aws.ohio
  
  cidr_block                       = "172.40.2.0/24"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name = "prisma-dicio"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "virginia" {
  provider = aws.virginia
  vpc_id   = aws_vpc.virginia.id

  tags = {
    Name = "prisma-dicio-igw-virginia"
  }
}

resource "aws_internet_gateway" "ohio" {
  provider = aws.ohio
  vpc_id   = aws_vpc.ohio.id

  tags = {
    Name = "prisma-dicio-igw-ohio"
  }
}

# Subnets públicas en Virginia
resource "aws_subnet" "virginia_public_1" {
  provider = aws.virginia
  
  vpc_id            = aws_vpc.virginia.id
  cidr_block        = "172.40.1.0/25"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "prisma-dicio-public-1a"
  }
}

resource "aws_subnet" "virginia_public_2" {
  provider = aws.virginia
  
  vpc_id            = aws_vpc.virginia.id
  cidr_block        = "172.40.1.128/25"
  availability_zone = "us-east-1b"

  map_public_ip_on_launch = true

  tags = {
    Name = "prisma-dicio-public-1b"
  }
}

# Subnets públicas en Ohio
resource "aws_subnet" "ohio_public_1" {
  provider = aws.ohio
  
  vpc_id            = aws_vpc.ohio.id
  cidr_block        = "172.40.2.0/25"
  availability_zone = "us-east-2a"

  map_public_ip_on_launch = true

  tags = {
    Name = "prisma-dicio-public-2a"
  }
}

resource "aws_subnet" "ohio_public_2" {
  provider = aws.ohio
  
  vpc_id            = aws_vpc.ohio.id
  cidr_block        = "172.40.2.128/25"
  availability_zone = "us-east-2b"

  map_public_ip_on_launch = true

  tags = {
    Name = "prisma-dicio-public-2b"
  }
}

# Route Tables
resource "aws_route_table" "virginia_public" {
  provider = aws.virginia
  vpc_id   = aws_vpc.virginia.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.virginia.id
  }

  tags = {
    Name = "prisma-dicio-rt-virginia"
  }
}

resource "aws_route_table" "ohio_public" {
  provider = aws.ohio
  vpc_id   = aws_vpc.ohio.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ohio.id
  }

  tags = {
    Name = "prisma-dicio-rt-ohio"
  }
}

# Route Table Associations
resource "aws_route_table_association" "virginia_public_1" {
  provider       = aws.virginia
  subnet_id      = aws_subnet.virginia_public_1.id
  route_table_id = aws_route_table.virginia_public.id
}

resource "aws_route_table_association" "virginia_public_2" {
  provider       = aws.virginia
  subnet_id      = aws_subnet.virginia_public_2.id
  route_table_id = aws_route_table.virginia_public.id
}

resource "aws_route_table_association" "ohio_public_1" {
  provider       = aws.ohio
  subnet_id      = aws_subnet.ohio_public_1.id
  route_table_id = aws_route_table.ohio_public.id
}

resource "aws_route_table_association" "ohio_public_2" {
  provider       = aws.ohio
  subnet_id      = aws_subnet.ohio_public_2.id
  route_table_id = aws_route_table.ohio_public.id
}

# Customer Gateway
resource "aws_customer_gateway" "main" {
  provider   = aws.virginia
  bgp_asn    = 65000
  ip_address = "34.103.72.46"
  type       = "ipsec.1"

  tags = {
    Name = "prisma-dicio-cgw"
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "virginia" {
  provider = aws.virginia
  vpc_id   = aws_vpc.virginia.id

  tags = {
    Name = "prisma-dicio-vgw"
  }
}

# VPN Connection con configuración detallada del túnel
resource "aws_vpn_connection" "main" {
  provider           = aws.virginia
  vpn_gateway_id     = aws_vpn_gateway.virginia.id
  customer_gateway_id = aws_customer_gateway.main.id
  type               = "ipsec.1"
  static_routes_only = true

  tunnel1_ike_versions = ["ikev2"]
  tunnel1_preshared_key = "Ain.dx5FIMYK_f5wTt6EoCLT.TrnAS"
  
  tunnel1_phase1_encryption_algorithms = ["AES128", "AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_lifetime_seconds     = 28800
  tunnel1_phase2_encryption_algorithms = ["AES128", "AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_lifetime_seconds     = 3600
  tunnel1_dpd_timeout_action          = "clear"

  tunnel2_ike_versions = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES128", "AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_lifetime_seconds     = 28800
  tunnel2_phase2_encryption_algorithms = ["AES128", "AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_lifetime_seconds     = 3600
  tunnel2_dpd_timeout_action          = "clear"

  tags = {
    Name = "prisma-dicio-vpn"
  }
}


# Security Group para EC2
resource "aws_security_group" "ec2" {
  provider    = aws.virginia
  name        = "prisma-dicio-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.virginia.id

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

  tags = {
    Name = "prisma-dicio-sg"
  }
}

# Key Pair
resource "aws_key_pair" "ssh" {
  provider   = aws.virginia
  key_name   = "prisma-dicio-key"
  public_key = file("~/.ssh/prisma-dicio-key.pub")
}

# EC2 Instance
resource "aws_instance" "app_server" {
  provider = aws.virginia
  
  ami           = "ami-0476ee53ea7bd56dc"
  instance_type = "m6i.2xlarge"
  
  subnet_id                   = aws_subnet.virginia_public_1.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                   = aws_key_pair.ssh.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ec2-user/Dicio/certs_consorcio/
              chown -R ec2-user:ec2-user /home/ec2-user/Dicio
              EOF

  tags = {
    Name = "prisma-dicio-server"
  }
}

# Output para obtener la IP pública y comando SSH
output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/prisma-dicio-key ec2-user@${aws_instance.app_server.public_ip}"
}
