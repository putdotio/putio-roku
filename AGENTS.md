# Agent Guide

## Repo

- Standalone Roku app repository for put.io
- Stack: BrightScript and SceneGraph

## Start Here

- [README.md](./README.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [SECURITY.md](./SECURITY.md)

## Commands

- `make verify`
- `make artifact`
- `make run`
- `make check-roku-dev-target`
- `make pkg`
- `make app-pkg`

## Rules

- Keep checked-in defaults open-source-safe
- Private device details, passwords, and signing keys stay out of git
- Update docs when setup, validation, or delivery expectations change

## Build And Config

- Local overrides flow through optional `.env`
- `.env.example` must stay sanitized and safe to publish
- `make verify` always builds a fresh zip and runs the desktop BrightScript checker when that tool is available locally

## CI

- `.github/workflows/ci.yml` is verify-only and should stay aligned with `make verify`
- `.github/workflows/deploy.yml` verifies first, then builds and publishes the release-style zip for default-branch pushes
