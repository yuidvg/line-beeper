resource "aws_route53_record" "matrix" {
  zone_id = var.route53_zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [aws_eip.matrix.public_ip]
}

# Well-known delegation for Matrix
resource "aws_route53_record" "matrix_srv" {
  zone_id = var.route53_zone_id
  name    = "_matrix._tcp.${var.domain}"
  type    = "SRV"
  ttl     = 300
  records = ["10 0 443 ${var.domain}"]
}
