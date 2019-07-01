data "aws_availability_zones" "available" {
}

## IAM:

## VPC:

resource "aws_default_vpc" "default-vpc" {
  enable_dns_support   = true
  enable_dns_hostnames = true
}

## Subnet:

resource "aws_vpc_ipv4_cidr_block_association" "secondary-cidr" {
  vpc_id     = aws_default_vpc.default-vpc.id
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "dev-subnet" {
  vpc_id                          = aws_vpc_ipv4_cidr_block_association.secondary-cidr.vpc_id
  cidr_block                      = cidrsubnet(var.vpc_cidr, 4, 1)
  ipv6_cidr_block                 = cidrsubnet(aws_default_vpc.default-vpc.ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true

  tags = {
    Project = var.project_name
    ManagedBy = "terraform"
  }
}

## Route Table:

data "aws_internet_gateway" "dev-igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [aws_default_vpc.default-vpc.id]
  }
}

resource "aws_default_route_table" "dev-rt" {
  default_route_table_id = aws_default_vpc.default-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.dev-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = data.aws_internet_gateway.dev-igw.id
  }

  tags = {
    Project = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "dev-rt-assoc" {
  subnet_id      = aws_subnet.dev-subnet.id
  route_table_id = aws_default_route_table.dev-rt.id
}

## Security Group:

resource "aws_security_group" "dev_security_group" {
  name   = "dev-instance"
  vpc_id = aws_default_vpc.default-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  # mosh
  ingress {
    from_port = 60000
    to_port   = 61000
    protocol  = "udp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Project = var.project_name
    ManagedBy = "terraform"
  }
}

## SSH Key pair:

resource "aws_key_pair" "dev_key_pair" {
  key_name   = var.dev_key_pair_name
  public_key = file("~/.ssh/${var.dev_key_pair_name}.pub")
}

## amazon2 AMI:

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# EFS
#resource "aws_efs_file_system" "dev-efs" {
#    creation_token = "dev-efs"
#    encrypted = true
#    ksm_key_id = "${var.dev_kms_arn}"
#    performance_mode = "generalPurpose"
#    throughput_mode = "bursting"
#
#    tags {
#        Project = "dev"
#    }
#}

## EC2:

resource "aws_instance" "dev_machine" {
  ami                         = data.aws_ami.amzn2.id
  instance_type               = var.dev_instance_type
  monitoring                  = false
  vpc_security_group_ids      = [aws_security_group.dev_security_group.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.dev-subnet.id
  key_name                    = aws_key_pair.dev_key_pair.id
  source_dest_check           = false

  provisioner "local-exec" {
    command = "sleep 60; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ec2-user --private-key ~/.ssh/${var.dev_key_pair_name}.pub -i '${aws_instance.dev_machine.public_ip},' dev_machine.yml"
  }

  tags = {
    Name = var.project_name
    Project = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.dev_machine.id
  vpc      = true

  tags = {
    Project = var.project_name
    ManagedBy = "terraform"
  }
}

## Add EC2 public IP to SSH config:

resource "null_resource" "add_to_ssh" {
  provisioner "local-exec" {
    command = "echo '' >> ~/.ssh/config ; echo 'Host aws-dev' >> ~/.ssh/config ; echo '  HostName ${aws_eip.eip.public_ip}' >> ~/.ssh/config ; echo '  User ec2-user' >> ~/.ssh/config ; echo '  IdentityFile ~/.ssh/${var.dev_key_pair_name}.pub' >> ~/.ssh/config"
  }

  depends_on = [aws_instance.dev_machine]
}

## scp AWS creds to EC2 dev instance:

resource "null_resource" "scp_ssh_aws" {
  provisioner "local-exec" {
    command = "scp ~/.ssh/${var.dev_key_pair_name} aws-dev:/home/ec2-user/.ssh/ ; scp ~/.aws/credentials aws-dev:/home/ec2-user/.aws/ ; scp ~/.aws/config aws-dev:/home/ec2-user/.aws/"
  }

  depends_on = [aws_instance.dev_machine]
}

## Remove EC2 public IP from SSH config:

resource "null_resource" "remove_from_ssh" {
  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '' -e '$ d' ~/.ssh/config ; sed -i '' -e '$ d' ~/.ssh/config ; sed -i '' -e '$ d' ~/.ssh/config ; sed -i '' -e '$ d' ~/.ssh/config"
  }
}

