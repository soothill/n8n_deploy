<!-- Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com -->

# Repository Guidelines

## Project Structure & Module Organization
- `README.md` is currently the only documented artifact; it should explain purpose and usage as the repo evolves.
- Keep top-level files focused and minimal. If you add source or scripts, group them by function (for example, `scripts/`, `config/`, `docs/`).
- Document any new directories in `README.md` and update this guide so contributors can find them quickly.

## Build, Test, and Development Commands
- No build, test, or runtime commands are defined yet.
- If you add a command, document it in `README.md` and list it here with a short description, e.g.:
  - `make build` — produce deployment artifacts.
  - `./scripts/deploy.sh` — run a local deployment workflow.

## Coding Style & Naming Conventions
- There are no established code style or linting rules in this repository.
- Follow conventional, readable formatting for any new files you introduce (for example, consistent indentation and clear file naming like `deploy.sh` or `config.sample.yml`).
- Prefer descriptive, lower-case names for scripts and configuration files.

## Testing Guidelines
- No automated tests or test frameworks are present.
- If you introduce tests, document the framework, the test directory, and the exact command to run them.

## Commit & Pull Request Guidelines
- Commit history is minimal and does not establish a convention. Use concise, imperative messages (e.g., "Add deployment script") and keep commits scoped.
- Pull requests should include:
  - A short summary of the change and rationale.
  - Any manual verification steps.
  - Notes about configuration changes or new secrets handling.

## Security & Configuration Tips
- Do not commit secrets. If configuration is added, prefer templated files like `.env.example` and document required variables in `README.md`.
- For deployment-related changes, spell out any required permissions or infrastructure assumptions.
