# Homelab

GitOps homelab. Argo CD pulls from this repo; nothing is deployed by hand
except Argo CD itself.

## Layout

    k3d/cluster.yaml        local throwaway cluster (1 server, 2 agents)
    bootstrap.sh            nothing -> running cluster + Argo CD + apps
    teardown.sh             delete the local cluster
    init.sh                 one-time: stamp your git remote into manifests
    clusters/local/         what THIS cluster runs (app-of-apps)
    apps/                   the actual workloads, cluster-agnostic

`clusters/` is the only place that differs per cluster. `apps/` is shared,
so a second cluster is a new folder under `clusters/`, not a fork.

## First run

    ./init.sh
    git commit -am "init" && git push
    ./bootstrap.sh

Then: `kubectl -n argocd port-forward svc/argocd-server 8081:443`

## Daily loop

Fast, no GitOps in the way:

    kubectl apply -k apps/podinfo

Real path: edit, commit, push, Argo CD syncs within ~3 minutes
(or `argocd app sync podinfo`).

Render without applying:

    kubectl kustomize apps/podinfo

## Adding an app

1. `apps/<name>/` with a kustomization.yaml
2. copy `clusters/local/apps/podinfo.yaml` -> `<name>.yaml`, change name + path
3. commit, push. The root app picks it up.

## Recovery

If the cluster is gone: install docker/k3d/kubectl, clone this repo,
run `./bootstrap.sh`. Anything not in git is lost by design - so
secrets belong in SOPS/sealed-secrets in this repo, with the master key
stored outside the cluster.
