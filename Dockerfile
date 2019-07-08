ARG tf_version=0.11.14
FROM hashicorp/terraform:${tf_version}
RUN apk --no-cache add bash && rm -rf /var/cache/apk/*

WORKDIR /project
ADD . .
RUN terraform init
RUN terraform validate -var-file=tests.tfvars
RUN terraform fmt -check=true -diff=true
