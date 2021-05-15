data "aws_vpc" "default" {
  default = var.vpc_id != "" ? false : true
  id = var.vpc_id != "" ? var.vpc_id : ""
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "aws_ami" "ubuntu" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

resource "aws_security_group" "allow_masq" {
  name        = "allow_masq"
  description = "Allow MASQ inbound traffic"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  ingress {
    description      = "MASQ from All"
    from_port        = var.clandestine_port
    to_port          = var.clandestine_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "masq_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [aws_security_group.allow_masq.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_role
  tags = {
    "Name" = var.name
  }
  user_data = templatefile("${path.module}/config.tpl", {
    chain            = var.chain
    bcsurl           = var.bcsurl
    clandestine_port = var.clandestine_port
    dbpass           = var.dbpass
    dnsservers       = var.dnsservers
    earnwallet       = var.earnwallet
    gasprice         = var.gasprice
    conkey           = var.conkey
  })
}