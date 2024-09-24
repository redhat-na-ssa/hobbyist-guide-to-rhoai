.PHONY: add-admin-user
add-admin-user:
	./bootcamp/scripts/setup-cluster.sh -u true

.PHONY: create-gpu-node
create-gpu-node:
	./bootcamp/scripts/setup-cluster.sh -g true

.PHONY: install-operators
install-operators:
	./bootcamp/scripts/setup-cluster.sh -o true

.PHONY: setup-cluster
setup-cluster:
	./bootcamp/scripts/setup-cluster.sh -a true
