.PHONY: add-admin-user
add-admin-user:
	./scripts/runstep.sh -s 1

.PHONY: setup-cluster
setup-cluster:
	./scripts/runstep.sh -s 0
