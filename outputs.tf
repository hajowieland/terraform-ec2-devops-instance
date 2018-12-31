output "public_ip" {
  description = "Public IPv4 address of dev machine instance"
  value       = ["${aws_instance.dev_machine.public_ip}"]
}

output "public_ipv6" {
  description = "Public IPv6 address of dev machine instance"
  value       = ["${aws_instance.dev_machine.ipv6_addresses}"]
}
