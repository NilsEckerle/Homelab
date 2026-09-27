.PHONY: interactive-shell verify

interactive-shell:
	docker compose run --rm --service-ports dind

verify:
	docker compose run --rm dind sh -c 'kubectl version --client && k3d version && docker info | head -5'
