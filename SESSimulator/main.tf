provider "aws" {
  region = "ap-northeast-1"
}

locals {
    domain = "matsuo.com"
}

resource "aws_sesv2_email_identity" "matsuo" {
  email_identity = "${local.domain}"
}

resource "aws_route53_zone" "primary" {
  name = "${local.domain}"
}

resource "aws_route53_record" "dkim" {
  count   = 3
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${element(aws_sesv2_email_identity.matsuo.dkim_signing_attributes[0].tokens, count.index)}._domainkey.hoge.com"
  type    = "CNAME"
  ttl     = 1800
  records = ["${element(aws_sesv2_email_identity.matsuo.dkim_signing_attributes[0].tokens, count.index)}.dkim.amazonses.com"]
}