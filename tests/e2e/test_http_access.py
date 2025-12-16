#!/usr/bin/env python3
"""
End-to-End Tests - HTTP Access and Redirects
Tests the complete HTTP flow and Nginx redirections
"""

import sys
import urllib.request
import urllib.error
from typing import Tuple

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def test_http_request(url: str, follow_redirects: bool = False, host_header: str = None) -> Tuple[int, str, dict]:
    """Make HTTP request and return status code, body, and headers"""
    try:
        req = urllib.request.Request(url)
        if host_header:
            req.add_header('Host', host_header)

        # Handle redirects
        if not follow_redirects:
            class NoRedirect(urllib.request.HTTPRedirectHandler):
                def redirect_request(self, req, fp, code, msg, headers, newurl):
                    return None
            opener = urllib.request.build_opener(NoRedirect)
            urllib.request.install_opener(opener)

        response = urllib.request.urlopen(req, timeout=10)
        status = response.status
        headers = dict(response.headers)
        body = response.read().decode('utf-8')
        return status, body, headers

    except urllib.error.HTTPError as e:
        return e.code, "", dict(e.headers)
    except Exception as e:
        print(f"  {Colors.RED}Error: {str(e)}{Colors.RESET}")
        return 0, "", {}

def test_localhost_redirect() -> bool:
    """Test that localhost:48580 redirects to press.localhost:48580"""
    print(f"\n🔍 Testing localhost redirect...")

    status, body, headers = test_http_request("http://localhost:48580", follow_redirects=False)

    if status == 301:
        location = headers.get('Location', '')
        if 'press.localhost:48580' in location:
            print(f"  {Colors.GREEN}✓{Colors.RESET} Redirect working: {location}")
            return True
        else:
            print(f"  {Colors.RED}✗{Colors.RESET} Wrong redirect location: {location}")
            return False
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Expected 301, got {status}")
        return False

def test_press_localhost_direct() -> bool:
    """Test direct access to press.localhost"""
    print(f"\n🔍 Testing press.localhost direct access...")

    status, body, headers = test_http_request("http://localhost:48580", host_header="press.localhost")

    if status == 200:
        if 'frappe' in body.lower() or 'erpnext' in body.lower() or 'login' in body.lower():
            print(f"  {Colors.GREEN}✓{Colors.RESET} Site accessible (HTTP 200)")
            print(f"  {Colors.GREEN}✓{Colors.RESET} Frappe/ERPNext content detected")
            return True
        else:
            print(f"  {Colors.YELLOW}⚠{Colors.RESET} HTTP 200 but unexpected content")
            return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Expected 200, got {status}")
        return False

def test_localhost_follow_redirect() -> bool:
    """Test full redirect flow from localhost to press.localhost"""
    print(f"\n🔍 Testing complete redirect flow...")

    status, body, headers = test_http_request("http://localhost:48580", follow_redirects=True)

    if status == 200:
        print(f"  {Colors.GREEN}✓{Colors.RESET} Redirect followed successfully (HTTP 200)")
        if 'frappe' in body.lower() or 'login' in body.lower():
            print(f"  {Colors.GREEN}✓{Colors.RESET} Frappe login page loaded")
            return True
        return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Redirect flow failed (HTTP {status})")
        return False

def test_nginx_configuration() -> bool:
    """Test Nginx configuration is properly loaded"""
    print(f"\n🔍 Testing Nginx configuration...")

    # Test that redirect config is mounted
    import subprocess
    result = subprocess.run(
        "podman exec fcs-press-frontend cat /etc/nginx/conf.d/localhost-redirect.conf",
        shell=True,
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        config = result.stdout
        if 'server_name localhost' in config and 'return 301' in config:
            print(f"  {Colors.GREEN}✓{Colors.RESET} Redirect configuration file present")
            print(f"  {Colors.GREEN}✓{Colors.RESET} Redirect rule found in config")
            return True
        else:
            print(f"  {Colors.RED}✗{Colors.RESET} Configuration file incomplete")
            return False
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Cannot read Nginx configuration")
        return False

def test_http_headers() -> bool:
    """Test HTTP security headers"""
    print(f"\n🔍 Testing HTTP headers...")

    status, body, headers = test_http_request("http://localhost:48580", host_header="press.localhost")

    checks_passed = 0
    checks_total = 0

    # Check for important headers
    header_checks = {
        'X-Frame-Options': ['DENY', 'SAMEORIGIN'],
        'X-Content-Type-Options': ['nosniff'],
    }

    for header, expected_values in header_checks.items():
        checks_total += 1
        if header in headers:
            if any(val in headers[header] for val in expected_values):
                print(f"  {Colors.GREEN}✓{Colors.RESET} {header}: {headers[header]}")
                checks_passed += 1
            else:
                print(f"  {Colors.YELLOW}⚠{Colors.RESET} {header}: {headers[header]} (unexpected value)")
        else:
            print(f"  {Colors.YELLOW}⚠{Colors.RESET} {header}: Not set")

    return checks_passed > 0  # At least some security headers should be present

def main():
    """Run all E2E tests"""
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BLUE}Press SaaS Platform - End-to-End Tests{Colors.RESET}")
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")

    tests_passed = []
    tests_failed = []

    # Test 1: Localhost Redirect
    print(f"\n{Colors.YELLOW}Test Suite 1: HTTP Redirects{Colors.RESET}")
    if test_localhost_redirect():
        tests_passed.append("Localhost redirect")
    else:
        tests_failed.append("Localhost redirect")

    # Test 2: Direct Access
    print(f"\n{Colors.YELLOW}Test Suite 2: Direct Access{Colors.RESET}")
    if test_press_localhost_direct():
        tests_passed.append("Direct access to press.localhost")
    else:
        tests_failed.append("Direct access to press.localhost")

    # Test 3: Follow Redirect
    print(f"\n{Colors.YELLOW}Test Suite 3: Complete Flow{Colors.RESET}")
    if test_localhost_follow_redirect():
        tests_passed.append("Complete redirect flow")
    else:
        tests_failed.append("Complete redirect flow")

    # Test 4: Nginx Config
    print(f"\n{Colors.YELLOW}Test Suite 4: Configuration{Colors.RESET}")
    if test_nginx_configuration():
        tests_passed.append("Nginx configuration")
    else:
        tests_failed.append("Nginx configuration")

    # Test 5: HTTP Headers
    print(f"\n{Colors.YELLOW}Test Suite 5: Security Headers{Colors.RESET}")
    if test_http_headers():
        tests_passed.append("HTTP security headers")
    else:
        tests_failed.append("HTTP security headers")

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
        return 1
    else:
        print(f"\n{Colors.GREEN}🎉 All E2E tests passed!{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
