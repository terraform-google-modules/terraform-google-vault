output instance_group {
  description = "Link to the `instance_group` property of the instance group manager resource."
  value       = "${module.vault-server.instance_group}"
}

output ca_private_key_algorithm {
  description = "The root CA algorithm for generating client certs."
  value       = "${tls_private_key.root.algorithm}"
}

output ca_private_key_pem {
  description = "The root CA key pem for generating client certs."
  value       = "${tls_private_key.root.private_key_pem}"
}

output ca_cert_pem {
  description = "The root CA cert pem for generating client certs."
  value       = "${tls_self_signed_cert.root.cert_pem}"
}
