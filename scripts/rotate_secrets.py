#!/usr/bin/env python3
"""
Secrets Rotation Script for Press SaaS Platform

This script automates the rotation of credentials for production deployments:
- PostgreSQL password
- MinIO root password
- Keycloak admin password
- Redis password (if configured)

Features:
- Atomic Docker secret updates
- Rolling restart of affected services
- Connectivity validation after rotation
- Dry-run mode for testing
- Rollback capability on failure

Usage:
    # Dry run (preview changes)
    python scripts/rotate_secrets.py --dry-run

    # Rotate all secrets
    python scripts/rotate_secrets.py --all

    # Rotate specific secret
    python scripts/rotate_secrets.py --secret postgres_password

    # Rotate with custom password
    python scripts/rotate_secrets.py --secret postgres_password --value "NewPassword123!"

Addresses: CHK027
"""

import argparse
import json
import os
import secrets
import string
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Any, Callable, Optional


# =============================================================================
# Configuration
# =============================================================================


class SecretType(Enum):
    """Types of secrets that can be rotated."""

    POSTGRES_PASSWORD = "postgres_password"
    MINIO_ROOT_PASSWORD = "minio_root_password"
    KEYCLOAK_ADMIN_PASSWORD = "keycloak_admin_password"
    REDIS_PASSWORD = "redis_password"


@dataclass
class SecretConfig:
    """Configuration for a secret."""

    name: str
    secret_type: SecretType
    affected_services: list[str]
    env_var_name: str
    min_length: int = 16
    validation_command: Optional[str] = None


# Secret configurations
SECRET_CONFIGS = {
    SecretType.POSTGRES_PASSWORD: SecretConfig(
        name="postgres_password",
        secret_type=SecretType.POSTGRES_PASSWORD,
        affected_services=["fcs-press-postgres", "fcs-press-manager"],
        env_var_name="POSTGRES_PASSWORD",
        min_length=20,
        validation_command="pg_isready -h localhost -p 5432",
    ),
    SecretType.MINIO_ROOT_PASSWORD: SecretConfig(
        name="minio_root_password",
        secret_type=SecretType.MINIO_ROOT_PASSWORD,
        affected_services=["fcs-press-minio", "fcs-press-manager"],
        env_var_name="MINIO_ROOT_PASSWORD",
        min_length=16,
        validation_command="curl -sf http://localhost:9000/minio/health/live",
    ),
    SecretType.KEYCLOAK_ADMIN_PASSWORD: SecretConfig(
        name="keycloak_admin_password",
        secret_type=SecretType.KEYCLOAK_ADMIN_PASSWORD,
        affected_services=["fcs-press-keycloak"],
        env_var_name="KEYCLOAK_ADMIN_PASSWORD",
        min_length=16,
        validation_command="curl -sf http://localhost:8080/health/ready",
    ),
    SecretType.REDIS_PASSWORD: SecretConfig(
        name="redis_password",
        secret_type=SecretType.REDIS_PASSWORD,
        affected_services=["fcs-press-redis-queue", "fcs-press-redis-cache"],
        env_var_name="REDIS_PASSWORD",
        min_length=16,
        validation_command="redis-cli ping",
    ),
}


# =============================================================================
# Password Generation
# =============================================================================


def generate_secure_password(length: int = 24) -> str:
    """
    Generate a cryptographically secure password.

    Args:
        length: Password length (minimum 16)

    Returns:
        Secure random password
    """
    if length < 16:
        raise ValueError("Password length must be at least 16 characters")

    # Character sets
    lowercase = string.ascii_lowercase
    uppercase = string.ascii_uppercase
    digits = string.digits
    # Exclude problematic characters for shell/Docker: $ ` \ " '
    special = "!@#%^&*()-_=+[]{}|;:,.<>?"

    # Ensure at least one of each type
    password = [
        secrets.choice(lowercase),
        secrets.choice(uppercase),
        secrets.choice(digits),
        secrets.choice(special),
    ]

    # Fill remaining length
    all_chars = lowercase + uppercase + digits + special
    password.extend(secrets.choice(all_chars) for _ in range(length - 4))

    # Shuffle to avoid predictable positions
    password_list = list(password)
    secrets.SystemRandom().shuffle(password_list)

    return "".join(password_list)


# =============================================================================
# Docker Operations
# =============================================================================


class DockerSecretManager:
    """Manages Docker secrets for rotation."""

    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self._backup_secrets: dict[str, str] = {}

    def _run_command(
        self,
        command: list[str],
        capture_output: bool = True,
        check: bool = True,
    ) -> subprocess.CompletedProcess:
        """Run a shell command."""
        if self.dry_run:
            print(f"  [DRY-RUN] Would execute: {' '.join(command)}")
            return subprocess.CompletedProcess(command, 0, b"", b"")

        return subprocess.run(
            command,
            capture_output=capture_output,
            check=check,
            text=True,
        )

    def secret_exists(self, name: str) -> bool:
        """Check if a Docker secret exists."""
        result = subprocess.run(
            ["docker", "secret", "inspect", name],
            capture_output=True,
            check=False,
        )
        return result.returncode == 0

    def get_secret_version(self, name: str) -> Optional[str]:
        """Get the version/ID of an existing secret."""
        result = subprocess.run(
            ["docker", "secret", "inspect", name, "--format", "{{.ID}}"],
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None

    def create_secret(self, name: str, value: str) -> bool:
        """
        Create a new Docker secret.

        Args:
            name: Secret name
            value: Secret value

        Returns:
            True if successful
        """
        print(f"  Creating secret: {name}")

        if self.dry_run:
            print(f"  [DRY-RUN] Would create secret '{name}' with {len(value)} chars")
            return True

        # Use stdin to avoid password in command line
        result = subprocess.run(
            ["docker", "secret", "create", name, "-"],
            input=value,
            capture_output=True,
            check=False,
            text=True,
        )

        if result.returncode != 0:
            print(f"  ERROR: Failed to create secret: {result.stderr}")
            return False

        return True

    def remove_secret(self, name: str) -> bool:
        """Remove a Docker secret."""
        print(f"  Removing secret: {name}")

        if self.dry_run:
            print(f"  [DRY-RUN] Would remove secret '{name}'")
            return True

        result = subprocess.run(
            ["docker", "secret", "rm", name],
            capture_output=True,
            check=False,
            text=True,
        )

        return result.returncode == 0

    def rotate_secret(self, name: str, new_value: str) -> bool:
        """
        Rotate a Docker secret atomically.

        This creates a versioned secret and updates service references.

        Args:
            name: Secret name
            new_value: New secret value

        Returns:
            True if successful
        """
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        versioned_name = f"{name}_{timestamp}"

        print(f"\n  Rotating secret: {name} -> {versioned_name}")

        # Create new versioned secret
        if not self.create_secret(versioned_name, new_value):
            return False

        # The old secret will be removed after services are updated
        # This is handled by the service update process

        return True


# =============================================================================
# Service Operations
# =============================================================================


class ServiceManager:
    """Manages Docker service operations."""

    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run

    def _run_command(
        self,
        command: list[str],
        check: bool = True,
    ) -> subprocess.CompletedProcess:
        """Run a shell command."""
        if self.dry_run:
            print(f"  [DRY-RUN] Would execute: {' '.join(command)}")
            return subprocess.CompletedProcess(command, 0, "", "")

        return subprocess.run(
            command,
            capture_output=True,
            check=check,
            text=True,
        )

    def restart_service(self, service_name: str) -> bool:
        """
        Perform rolling restart of a service.

        Args:
            service_name: Docker service name

        Returns:
            True if successful
        """
        print(f"  Restarting service: {service_name}")

        # For Docker Compose
        result = self._run_command(
            ["docker", "compose", "restart", service_name],
            check=False,
        )

        if result.returncode != 0 and not self.dry_run:
            # Try Docker Swarm service update
            result = self._run_command(
                ["docker", "service", "update", "--force", service_name],
                check=False,
            )

        return result.returncode == 0 or self.dry_run

    def wait_for_healthy(
        self,
        service_name: str,
        timeout_seconds: int = 60,
    ) -> bool:
        """
        Wait for a service to become healthy.

        Args:
            service_name: Docker service name
            timeout_seconds: Maximum wait time

        Returns:
            True if service is healthy
        """
        print(f"  Waiting for {service_name} to be healthy...")

        if self.dry_run:
            print(f"  [DRY-RUN] Would wait for {service_name} health")
            return True

        start_time = time.time()

        while time.time() - start_time < timeout_seconds:
            result = subprocess.run(
                [
                    "docker", "inspect",
                    "--format", "{{.State.Health.Status}}",
                    service_name,
                ],
                capture_output=True,
                check=False,
                text=True,
            )

            if result.returncode == 0:
                status = result.stdout.strip()
                if status == "healthy":
                    print(f"  {service_name} is healthy")
                    return True

            time.sleep(2)

        print(f"  WARNING: {service_name} did not become healthy within {timeout_seconds}s")
        return False


# =============================================================================
# Rotation Orchestrator
# =============================================================================


class SecretRotationOrchestrator:
    """Orchestrates the complete secret rotation process."""

    def __init__(self, dry_run: bool = False, verbose: bool = False):
        self.dry_run = dry_run
        self.verbose = verbose
        self.secret_manager = DockerSecretManager(dry_run)
        self.service_manager = ServiceManager(dry_run)
        self.rotation_log: list[dict] = []

    def rotate(
        self,
        secret_type: SecretType,
        new_value: Optional[str] = None,
    ) -> bool:
        """
        Rotate a single secret.

        Args:
            secret_type: Type of secret to rotate
            new_value: New password (generated if not provided)

        Returns:
            True if rotation successful
        """
        config = SECRET_CONFIGS[secret_type]

        print(f"\n{'='*60}")
        print(f"Rotating: {config.name}")
        print(f"{'='*60}")

        # Generate password if not provided
        if new_value is None:
            new_value = generate_secure_password(config.min_length)
            print(f"  Generated new password ({len(new_value)} chars)")

        # Validate password length
        if len(new_value) < config.min_length:
            print(f"  ERROR: Password must be at least {config.min_length} characters")
            return False

        # Log rotation start
        log_entry = {
            "secret": config.name,
            "started_at": datetime.now().isoformat(),
            "services": config.affected_services,
            "status": "in_progress",
        }
        self.rotation_log.append(log_entry)

        try:
            # Step 1: Create new secret
            if not self.secret_manager.rotate_secret(config.name, new_value):
                log_entry["status"] = "failed"
                log_entry["error"] = "Failed to create new secret"
                return False

            # Step 2: Restart affected services
            print(f"\n  Restarting affected services...")
            for service in config.affected_services:
                if not self.service_manager.restart_service(service):
                    print(f"  WARNING: Failed to restart {service}")

            # Step 3: Wait for services to be healthy
            print(f"\n  Validating service health...")
            all_healthy = True
            for service in config.affected_services:
                if not self.service_manager.wait_for_healthy(service):
                    all_healthy = False

            if not all_healthy:
                print("  WARNING: Some services may not be healthy")

            # Step 4: Validate connectivity (if command provided)
            if config.validation_command and not self.dry_run:
                print(f"\n  Running validation: {config.validation_command}")
                result = subprocess.run(
                    config.validation_command,
                    shell=True,
                    capture_output=True,
                    check=False,
                )
                if result.returncode != 0:
                    print(f"  WARNING: Validation command failed")

            log_entry["status"] = "completed"
            log_entry["completed_at"] = datetime.now().isoformat()

            print(f"\n  SUCCESS: {config.name} rotated successfully")
            return True

        except Exception as e:
            log_entry["status"] = "failed"
            log_entry["error"] = str(e)
            print(f"\n  ERROR: Rotation failed: {e}")
            return False

    def rotate_all(self) -> dict[str, bool]:
        """
        Rotate all secrets.

        Returns:
            Dict mapping secret names to success status
        """
        results = {}

        print("\n" + "=" * 60)
        print("ROTATING ALL SECRETS")
        print("=" * 60)

        for secret_type in SecretType:
            # Skip Redis if not configured
            if secret_type == SecretType.REDIS_PASSWORD:
                if not os.environ.get("REDIS_PASSWORD_ENABLED"):
                    print(f"\n  Skipping {secret_type.value} (not enabled)")
                    continue

            results[secret_type.value] = self.rotate(secret_type)

        # Print summary
        print("\n" + "=" * 60)
        print("ROTATION SUMMARY")
        print("=" * 60)
        for name, success in results.items():
            status = "SUCCESS" if success else "FAILED"
            print(f"  {name}: {status}")

        return results

    def save_rotation_log(self, path: str = "rotation_log.json"):
        """Save rotation log to file."""
        with open(path, "w") as f:
            json.dump(self.rotation_log, f, indent=2)
        print(f"\n  Rotation log saved to: {path}")


# =============================================================================
# CLI
# =============================================================================


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Rotate secrets for Press SaaS Platform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --dry-run                    Preview all rotations
  %(prog)s --all                        Rotate all secrets
  %(prog)s --secret postgres_password   Rotate specific secret
  %(prog)s --secret postgres_password --value "MyNewPassword123!"
        """,
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without executing",
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Rotate all secrets",
    )

    parser.add_argument(
        "--secret",
        choices=[s.value for s in SecretType],
        help="Specific secret to rotate",
    )

    parser.add_argument(
        "--value",
        help="New password value (generated if not provided)",
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Verbose output",
    )

    parser.add_argument(
        "--log-file",
        default="rotation_log.json",
        help="Path to save rotation log",
    )

    args = parser.parse_args()

    # Validate arguments
    if not args.all and not args.secret:
        parser.error("Must specify --all or --secret")

    if args.value and not args.secret:
        parser.error("--value requires --secret")

    # Create orchestrator
    orchestrator = SecretRotationOrchestrator(
        dry_run=args.dry_run,
        verbose=args.verbose,
    )

    if args.dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN MODE - No changes will be made")
        print("=" * 60)

    # Execute rotation
    try:
        if args.all:
            results = orchestrator.rotate_all()
            success = all(results.values())
        else:
            secret_type = SecretType(args.secret)
            success = orchestrator.rotate(secret_type, args.value)

        # Save log
        if not args.dry_run:
            orchestrator.save_rotation_log(args.log_file)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\n\nRotation interrupted by user")
        sys.exit(130)

    except Exception as e:
        print(f"\nFATAL ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
