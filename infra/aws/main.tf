resource "random_string" "random_prefix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = false
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.project_name}-${random_string.random_prefix.result}"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.zone
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "${var.project_name}-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.tags, {
    Name = "${var.project_name}_igw"
  })
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}_rt"
  })
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "${var.project_name}-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DOCKER_DAEMON"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "KUBERNETES_API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg"
  })
}

resource "aws_key_pair" "single_vm" {
  key_name   = "${var.project_name}-key"
  public_key = file("${var.ssh.key}")

  tags = merge(var.tags, {
    Name = "${var.project_name}-key"
  })
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "single_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_machine_type
  availability_zone      = var.zone
  subnet_id              = aws_subnet.subnet.id
  key_name               = aws_key_pair.single_vm.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]

  associate_public_ip_address = true
  source_dest_check           = false

  user_data = templatefile("${path.module}/templates/docker-cloud-init.tpl", {
    docker_port = var.docker_port
    hostname    = var.vm_name
    ssh_user    = var.ssh.user
    ssh_key     = file("${var.ssh.key}")
  })

  root_block_device {
    volume_type           = "standard"
    volume_size           = "20"
    delete_on_termination = "true"
  }

  tags = merge(var.tags, {
    Name = var.vm_name
  })

  volume_tags = merge(var.tags, {
    Name = var.vm_name
  })
}

resource "null_resource" "wait_for_docker_ready" {
  triggers = {
    instance_id = aws_instance.single_vm.id
    public_ip   = aws_instance.single_vm.public_ip
    always_run  = timestamp()
  }
  provisioner "local-exec" {
    command     = <<EOT
      count=0
      max_count=30
      until echo > /dev/tcp/${aws_instance.single_vm.public_ip}/${var.docker_port} || [ $count -eq $max_count ]; do
        echo "Waiting for port ${var.docker_port}... (count: $count)"
        sleep 10
        count=$((count+1))
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [aws_instance.single_vm]
}
