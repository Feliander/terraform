## Intro
Local micro infrastructure. Based on qemu/kvm hypervisor.

## What's inside?

### 1. Nginx

Only one web entrypoint.
Must be configured with [ansible nginx role](https://github.com/Feliander/ansible?tab=readme-ov-file#install-pyenv-and-any-python-version).

### 2. Simple backend

Simple python http server for nginx testing.

## Is that all?

For now, yes. In the future, it will include at least gitlab, k8s, vault, and observability tools.