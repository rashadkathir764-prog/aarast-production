# Deployment Plan

This document is planning-only. It does not create Dockerfiles, docker-compose files, Dokploy configuration, deployment scripts, or runtime infrastructure.

## Prerequisites

Deployment work must not begin until the correct Git repository root is confirmed. This prevents deployment files, environment references, and operational decisions from being attached to the wrong folder or subproject.

## Local Environment Isolation

Docker will be used for local environment isolation and reproducible runtime environments. The goal is to keep project services predictable across development machines and avoid accidental reliance on unrelated local services.

## VPS Deployment Direction

Dokploy will be used for later VPS deployment and operations. Dokploy is a deployment platform choice for a future phase, not an implementation task in the current Docs Foundation phase.

## Environment Staging

Future deployment planning must distinguish between development, staging, and production environments.

- Development is for local and early integration checks.
- Staging is for production-like validation before release.
- Production is for real users and must not be the first deployment target.

## Secrets Discipline

- Do not commit `.env` files.
- Do not write production secrets in Markdown.
- Do not commit database passwords, JWT secrets, API keys, or Dokploy secrets.
- Runtime secrets must be managed through environment variables or the deployment platform in a later approved phase.

## Current Phase Boundary

During Docs Foundation:

- No Dockerfile should be created unless explicitly requested.
- No docker-compose file should be created unless explicitly requested.
- No Dokploy configuration should be created unless explicitly requested.
- No deployment scripts should be created unless explicitly requested.
- No application code, backend modules, Flutter screens, package installs, or migrations should be added.

## Deferral Rule

Deployment is deferred until the backend and mobile MVP foundations are clearer. Docker and Dokploy implementation should happen only in a later deployment-readiness phase after the Wedding Financial OS MVP foundation is stable enough to deploy and verify.

## Production Deployment Requirements

Before production deployment, Aarast must document:

- Environment variables.
- Domains and DNS.
- Database configuration.
- File and object storage.
- Backups and restore process.
- Logs and operational visibility.
- Rollback process.
- Smoke checks after deployment.

## Database Safety

Production migrations must require a documented backup and rollback plan before execution.

## Post-Deployment Verification

Every deployment must run post-deploy smoke checks before being considered successful. A deployment is not complete until the critical health, authentication, API, and affected feature checks pass in the target environment.
