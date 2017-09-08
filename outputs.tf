/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
