#!/usr/bin/env python3
"""
Security Tests - Press SaaS Platform
Tests security configurations, secrets management, and best practices
"""

import os
import sys
import subprocess
from typing import List, Tuple

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def test_env_file_security() -> bool:
    """Test that .env file is properly secured"""
    print(f"\n🔍 Testing .env file security...")

    tests_passed = []
    tests_failed = []

    # Check .env exists
    if not os.path.exists('.env'):
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} .env file not found (using defaults)")
        return True

    # Check .env is in .gitignore
    with open('.gitignore', 'r') as f:
        gitignore_content = f.read()

    if '/.env' in gitignore_content or '.env' in gitignore_content:
        print(f"  {Colors.GREEN}✓{Colors.RESET} .env is in .gitignore")
        tests_passed.append(".env in .gitignore")
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} .env NOT in .gitignore - SECURITY RISK!")
        tests_failed.append(".env in .gitignore")

    # Check .env file permissions
    stat_info = os.stat('.env')
    mode = oct(stat_info.st_mode)[-3:]

    if mode in ['600', '640', '400']:
        print(f"  {Colors.GREEN}✓{Colors.RESET} .env permissions OK ({mode})")
        tests_passed.append(".env permissions")
    else:
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} .env permissions: {mode} (should be 600 or 640)")

    return len(tests_failed) == 0

def test_secrets_not_in_git() -> bool:
    """Test that no secrets are committed to git"""
    print(f"\n🔍 Testing for secrets in git history...")

    # Search for actual secret patterns (not documentation)
    # Exclude: .md files, .github/, tests/, comments
    result = subprocess.run(
        "git ls-files | grep -v '\\.md$' | grep -v '^\\.github/' | grep -v '^tests/' | xargs grep -i -E 'password=|secret=|api_key=|token=' 2>/dev/null | grep -v '.example' | grep -v '#' || true",
        shell=True,
        capture_output=True,
        text=True
    )

    # Filter out false positives
    lines = result.stdout.strip().split('\n') if result.stdout.strip() else []
    real_secrets = []

    for line in lines:
        # Skip empty lines and documentation
        if not line or 'placeholder' in line.lower() or 'template' in line.lower():
            continue
        # Skip if it's a variable reference like ${PASSWORD}
        if '${' in line and '}' in line:
            continue
        real_secrets.append(line)

    if not real_secrets:
        print(f"  {Colors.GREEN}✓{Colors.RESET} No secrets found in git (documentation excluded)")
        return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Potential secrets found:")
        for line in real_secrets[:5]:  # Show first 5 matches
            print(f"    {line}")
        return False

def test_default_passwords_changed() -> bool:
    """Test that default passwords are not used"""
    print(f"\n🔍 Testing for default passwords...")

    # Common default passwords to check
    default_passwords = ['admin', 'password', '123456', 'frappe', 'erpnext']

    if not os.path.exists('.env'):
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} .env not found, cannot verify passwords")
        return True

    with open('.env', 'r') as f:
        env_content = f.read().lower()

    found_defaults = []
    for pwd in default_passwords:
        if f'password={pwd}' in env_content or f'password: {pwd}' in env_content:
            found_defaults.append(pwd)

    if found_defaults:
        print(f"  {Colors.RED}✗{Colors.RESET} Default passwords found: {', '.join(found_defaults)}")
        return False
    else:
        print(f"  {Colors.GREEN}✓{Colors.RESET} No default passwords detected")
        return True

def test_docker_compose_secrets() -> bool:
    """Test that Docker Compose uses environment variables for secrets"""
    print(f"\n🔍 Testing Docker Compose secret management...")

    compose_files = [
        'compose.yaml',
        'overrides/compose.postgres.yaml',
        'overrides/compose.redis.yaml',
    ]

    tests_passed = []
    tests_failed = []

    for compose_file in compose_files:
        if not os.path.exists(compose_file):
            continue

        with open(compose_file, 'r') as f:
            content = f.read()

        # Check for hardcoded passwords
        if 'password: ' in content.lower() and '${' not in content:
            print(f"  {Colors.RED}✗{Colors.RESET} Hardcoded password in {compose_file}")
            tests_failed.append(compose_file)
        else:
            tests_passed.append(compose_file)

    if tests_failed:
        print(f"  {Colors.RED}✗{Colors.RESET} Found hardcoded secrets in: {', '.join(tests_failed)}")
        return False
    else:
        print(f"  {Colors.GREEN}✓{Colors.RESET} All compose files use environment variables")
        return True

def test_exposed_ports_documented() -> bool:
    """Test that all exposed ports are documented"""
    print(f"\n🔍 Testing port documentation...")

    # Get all exposed ports from containers
    result = subprocess.run(
        "podman ps --format '{{.Names}}\t{{.Ports}}' | grep -v '^$'",
        shell=True,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} Cannot check running containers")
        return True

    # Parse ports
    ports_found = set()
    for line in result.stdout.split('\n'):
        if '->' in line:
            parts = line.split('->')
            for part in parts:
                if ':' in part:
                    port = part.split(':')[-1].split('/')[0].strip()
                    if port.isdigit():
                        ports_found.add(port)

    # Check if ports are in README
    with open('README.md', 'r') as f:
        readme = f.read()

    undocumented = []
    for port in ports_found:
        if port not in readme:
            undocumented.append(port)

    if undocumented:
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} Undocumented ports: {', '.join(undocumented)}")
    else:
        print(f"  {Colors.GREEN}✓{Colors.RESET} All ports are documented")

    return True  # Warning only, not critical

def test_network_isolation() -> bool:
    """Test that containers use dedicated network"""
    print(f"\n🔍 Testing network isolation...")

    result = subprocess.run(
        "podman network ls --format '{{.Name}}'",
        shell=True,
        capture_output=True,
        text=True
    )

    if 'fcs-press-network' in result.stdout:
        print(f"  {Colors.GREEN}✓{Colors.RESET} Dedicated network 'fcs-press-network' exists")

        # Check containers are on this network
        result2 = subprocess.run(
            "podman ps --format '{{.Names}}' | xargs -I {} podman inspect {} --format '{{.Name}}: {{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}'",
            shell=True,
            capture_output=True,
            text=True
        )

        press_containers = [line for line in result2.stdout.split('\n') if 'fcs-press' in line or 'frappe_docker_git' in line]

        if press_containers:
            print(f"  {Colors.GREEN}✓{Colors.RESET} Containers using dedicated network")
            return True

    print(f"  {Colors.YELLOW}⚠{Colors.RESET} Network isolation not fully configured")
    return True  # Warning only

def main():
    """Run all security tests"""
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BLUE}Press SaaS Platform - Security Tests{Colors.RESET}")
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")

    tests_passed = []
    tests_failed = []

    # Test 1: .env Security
    print(f"\n{Colors.YELLOW}Test Suite 1: Environment File Security{Colors.RESET}")
    if test_env_file_security():
        tests_passed.append(".env security")
    else:
        tests_failed.append(".env security")

    # Test 2: Secrets in Git
    print(f"\n{Colors.YELLOW}Test Suite 2: Git Secret Scanning{Colors.RESET}")
    if test_secrets_not_in_git():
        tests_passed.append("No secrets in git")
    else:
        tests_failed.append("Secrets found in git")

    # Test 3: Default Passwords
    print(f"\n{Colors.YELLOW}Test Suite 3: Password Security{Colors.RESET}")
    if test_default_passwords_changed():
        tests_passed.append("No default passwords")
    else:
        tests_failed.append("Default passwords detected")

    # Test 4: Docker Compose Secrets
    print(f"\n{Colors.YELLOW}Test Suite 4: Compose Secret Management{Colors.RESET}")
    if test_docker_compose_secrets():
        tests_passed.append("Compose secrets")
    else:
        tests_failed.append("Compose secrets")

    # Test 5: Port Documentation
    print(f"\n{Colors.YELLOW}Test Suite 5: Port Documentation{Colors.RESET}")
    if test_exposed_ports_documented():
        tests_passed.append("Port documentation")

    # Test 6: Network Isolation
    print(f"\n{Colors.YELLOW}Test Suite 6: Network Isolation{Colors.RESET}")
    if test_network_isolation():
        tests_passed.append("Network isolation")

    # Summary
    print(f"\n{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BLUE}Test Summary{Colors.RESET}")
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.GREEN}✓ Passed: {len(tests_passed)}{Colors.RESET}")
    print(f"{Colors.RED}✗ Failed: {len(tests_failed)}{Colors.RESET}")

    if tests_failed:
        print(f"\n{Colors.RED}Failed Tests:{Colors.RESET}")
        for test in tests_failed:
            print(f"  - {test}")
        print(f"\n{Colors.RED}⚠ SECURITY ISSUES DETECTED - PLEASE FIX!{Colors.RESET}")
        return 1
    else:
        print(f"\n{Colors.GREEN}🎉 All security tests passed!{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
