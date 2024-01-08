# Changelog
All notable changes to this project will be documented in this file.
The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [7.0.1](https://github.com/terraform-google-modules/terraform-google-vault/compare/v7.0.0...v7.0.1) (2023-10-20)


### Bug Fixes

* upgraded versions.tf to include minor bumps from tpg v5 ([#193](https://github.com/terraform-google-modules/terraform-google-vault/issues/193)) ([16b77b0](https://github.com/terraform-google-modules/terraform-google-vault/commit/16b77b0f3c8dcb24d5877371d0aa37f7b7ffed61))

## [7.0.0](https://github.com/terraform-google-modules/terraform-google-vault/compare/v6.2.0...v7.0.0) (2023-04-13)


### ⚠ BREAKING CHANGES

* **TPG >= 4.53:** set bgp keepalive_interval to default 20 ([#169](https://github.com/terraform-google-modules/terraform-google-vault/issues/169))

### Features

* support shared VPC with allow_public_egress ([#174](https://github.com/terraform-google-modules/terraform-google-vault/issues/174)) ([defb7c6](https://github.com/terraform-google-modules/terraform-google-vault/commit/defb7c6f8df48150c2c999d4dda493a9371c56ae))


### Bug Fixes

* **TPG >= 4.53:** set bgp keepalive_interval to default 20 ([#169](https://github.com/terraform-google-modules/terraform-google-vault/issues/169)) ([aaf6bc6](https://github.com/terraform-google-modules/terraform-google-vault/commit/aaf6bc65a4b9e5ef9d2765157f08e2ed015d1e60))
* updates for tflint and dev-tools 1.11 ([#180](https://github.com/terraform-google-modules/terraform-google-vault/issues/180)) ([a2fb9b8](https://github.com/terraform-google-modules/terraform-google-vault/commit/a2fb9b8ade379bbd57488dde263203c8ce623345))

## [6.2.0](https://github.com/terraform-google-modules/terraform-google-vault/compare/v6.1.3...v6.2.0) (2022-11-29)


### Features

* allow tls_save_ca_to_disk to also chose the filename of the full path of the local CA public certificate copy ([#165](https://github.com/terraform-google-modules/terraform-google-vault/issues/165)) ([3f78888](https://github.com/terraform-google-modules/terraform-google-vault/commit/3f78888082b05e6aa0bd2326d03d40851b3c46fb))


### Bug Fixes

* widen minimum TLS version ([#166](https://github.com/terraform-google-modules/terraform-google-vault/issues/166)) ([9cb383b](https://github.com/terraform-google-modules/terraform-google-vault/commit/9cb383ba74cbfe8c5dcefe73270a73f7cffbea80))

## [6.1.3](https://github.com/terraform-google-modules/terraform-google-vault/compare/v6.1.2...v6.1.3) (2022-07-28)


### Bug Fixes

* Replace template_file with templatefile ([#153](https://github.com/terraform-google-modules/terraform-google-vault/issues/153)) ([0d02664](https://github.com/terraform-google-modules/terraform-google-vault/commit/0d02664d837b872fb5dd39dfa2f1144fb03fb7a3)), closes [#152](https://github.com/terraform-google-modules/terraform-google-vault/issues/152)

### [6.1.2](https://github.com/terraform-google-modules/terraform-google-vault/compare/v6.1.1...v6.1.2) (2022-04-21)


### Bug Fixes

* Update TLS to use v3.3 which includes support for linux_arm64 ([#147](https://github.com/terraform-google-modules/terraform-google-vault/issues/147)) ([9236c4a](https://github.com/terraform-google-modules/terraform-google-vault/commit/9236c4ae01a99617053a9e0bb8cc47df30ee1544))

### [6.1.1](https://github.com/terraform-google-modules/terraform-google-vault/compare/v6.1.0...v6.1.1) (2022-01-13)


### Bug Fixes

* move Google provider from the module definition and fixed a couple typos ([#141](https://github.com/terraform-google-modules/terraform-google-vault/issues/141)) ([b031761](https://github.com/terraform-google-modules/terraform-google-vault/commit/b031761253aaac5b2b21f55ff05b06615d73f06e))

## [6.1.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v6.0.0...v6.1.0) (2021-12-02)


### Features

* update TPG version constraints to allow 4.0 ([#133](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/133)) ([a1a53fb](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/a1a53fbc1de2f0598c035b425751998169553e48))

## [6.0.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v5.3.0...v6.0.0) (2021-07-11)


### ⚠ BREAKING CHANGES

* Minimum Terraform version increased to 0.13.

### Features

* add Terraform 0.13 constraint and module attribution ([#128](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/128)) ([008ef77](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/008ef77fe09d1e6cf31f565ef91bdec86f7e671f))

## [5.3.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v5.2.0...v5.3.0) (2021-02-15)


### Features

* add vault_update_policy_type parameter ([#125](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/125)) ([d25ae6a](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/d25ae6a1ab8f4f1c64acfe1af198663ea17b5a12))

## [5.2.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v5.1.0...v5.2.0) (2020-11-16)


### Features

* enable auto-healing, update to Debian 10 ([#119](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/119)) ([1d0b5db](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/1d0b5db7f310dc6a47af3130a97e5373d9cdaddf))

## [5.1.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v5.0.1...v5.1.0) (2020-08-20)


### Features

* Support service_label for internal load balancer ([#106](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/106)) ([07c0e89](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/07c0e896181ddf68fa22d646447932bd938569af))

### [5.0.1](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/v5.0.0...v5.0.1) (2020-07-29)


### Bug Fixes

* fixed outputs wrong vault_lb_addr ([#102](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/102)) ([5afdbc7](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/5afdbc785b54c567f4180c75fce0874ff6700004))

## [5.0.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/4.2.0...v5.0.0) (2020-07-21)


### ⚠ BREAKING CHANGES

* Pulled Vault core into a separate submodule (#99)

### Features

* Pulled Vault core into a separate submodule ([#99](https://www.github.com/terraform-google-modules/terraform-google-vault/issues/99)) ([b4b39ab](https://www.github.com/terraform-google-modules/terraform-google-vault/commit/b4b39ab4ebf69dfdb3479c3da321808d767981ce))

## [v4.2.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/4.1.0...4.2.0) (2020-06-18)

## [v4.1.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/4.0.0...4.1.0) (2020-05-28)

## [v4.0.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.1.3...4.0.0) (2020-04-02)

## [v3.1.3](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.1.2...3.1.3) (2020-01-13)

## [v3.1.2](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.1.1...3.1.2) (2019-12-26)

## [v3.1.1](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.1.0...3.1.1) (2019-12-11)

## [v3.1.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.0.3...3.1.0) (2019-12-09)

## [v3.0.3](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.0.2...3.0.3) (2019-10-01)

## [v3.0.2](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.0.1...3.0.2) (2019-09-16)

## [v3.0.1](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/3.0.0...3.0.1) (2019-09-16)

## [v3.0.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/2.1.0...3.0.0) (2019-08-15)

## [v2.1.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/2.0.2...2.1.0) (2019-05-24)

## [v2.0.2](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/2.0.1...2.0.2) (2019-03-21)

## [v2.0.1](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/2.0.0...2.0.1) (2019-03-07)

## [v2.0.0](https://www.github.com/terraform-google-modules/terraform-google-vault/compare/1.0.0...2.0.0) (2019-03-04)
