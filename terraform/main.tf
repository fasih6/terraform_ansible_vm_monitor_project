resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = "ami-0b6c6ebed2801a5cb"
  instance_type = "t3.micro"
  vpc_security_group_ids = ["sg-0cffc6ab3061c2c9b"]

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    public_key = file("${path.module}/ans_master_1.pub")
  })

  tags = {
    Name        = "web-${count.index + 1}"
    Environment = "dev"
    Role        = "web"
  }
}
