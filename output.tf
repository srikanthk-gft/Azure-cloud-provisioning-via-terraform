output "gft-demo-ss_public_ip" {
  value = "${azurerm_public_ip.gft-demo-ss.id}"
}

output "gft-demo-jb_public_ip" {
  value = "${azurerm_public_ip.gft-demo-jb.id}"
}