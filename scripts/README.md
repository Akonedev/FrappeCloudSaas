Repository scripts
==================

This folder includes helper and validation scripts used by CI and locally.

Current scripts:
- validate_container_names.sh — ensures service names or container_name values start with fcs-press-
- validate_ports.sh — ensures host-exposed ports are inside 48510-49800

Usage: run scripts locally to validate compose files before committing. These scripts are also run in CI.
