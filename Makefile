.PHONY: init fmt validate plan apply destroy

init:
	terraform init

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy
