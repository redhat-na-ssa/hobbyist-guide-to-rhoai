.PHONY: add-admin-user
add-admin-user:
	./scripts/setup.sh -s 1

.PHONY: setup-cluster
setup-cluster:
	./scripts/setup.sh -s 0
