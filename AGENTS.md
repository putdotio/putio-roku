# Agent Guide

## Repo

- Standalone Roku app repository for put.io
- Stack: BrightScript and SceneGraph

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Security](./SECURITY.md)

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
- `.github/workflows/release.yml` verifies first, then semantic-release publishes official ZIPs only when a release is due
- `https://roku.put.io/v2.zip` is the latest official released v2 sideload ZIP
