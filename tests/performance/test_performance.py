#!/usr/bin/env python3
"""
Performance Tests - Press SaaS Platform
Tests response times, resource usage, and performance metrics
"""

import sys
import time
import urllib.request
import urllib.error
from typing import List, Tuple

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def measure_response_time(url: str, host_header: str = None, iterations: int = 5) -> List[float]:
    """Measure HTTP response time over multiple iterations"""
    times = []

    for i in range(iterations):
        try:
            req = urllib.request.Request(url)
            if host_header:
                req.add_header('Host', host_header)

            start = time.time()
            response = urllib.request.urlopen(req, timeout=10)
            _ = response.read()
            end = time.time()

            elapsed = (end - start) * 1000  # Convert to ms
            times.append(elapsed)

        except Exception as e:
            print(f"  {Colors.RED}Error on iteration {i+1}: {str(e)}{Colors.RESET}")
            continue

    return times

def test_http_response_time() -> bool:
    """Test HTTP response time is acceptable"""
    print(f"\n🔍 Testing HTTP response time...")

    times = measure_response_time("http://localhost:48580", host_header="press.localhost", iterations=5)

    if not times:
        print(f"  {Colors.RED}✗{Colors.RESET} No successful requests")
        return False

    avg_time = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)

    print(f"  Response times (ms):")
    print(f"    Average: {avg_time:.2f}ms")
    print(f"    Min:     {min_time:.2f}ms")
    print(f"    Max:     {max_time:.2f}ms")

    # Check if average response time is acceptable (< 2000ms)
    if avg_time < 2000:
        print(f"  {Colors.GREEN}✓{Colors.RESET} Response time is acceptable")
        return True
    elif avg_time < 5000:
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} Response time is slower than ideal")
        return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Response time is too slow (>{avg_time:.0f}ms)")
        return False

def test_redirect_performance() -> bool:
    """Test redirect performance"""
    print(f"\n🔍 Testing redirect performance...")

    times = measure_response_time("http://localhost:48580", iterations=5)

    if not times:
        print(f"  {Colors.RED}✗{Colors.RESET} No successful redirects")
        return False

    avg_time = sum(times) / len(times)

    print(f"  Redirect time: {avg_time:.2f}ms (avg)")

    # Redirects should be very fast (< 100ms)
    if avg_time < 100:
        print(f"  {Colors.GREEN}✓{Colors.RESET} Redirect is fast")
        return True
    elif avg_time < 500:
        print(f"  {Colors.YELLOW}⚠{Colors.RESET} Redirect could be faster")
        return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Redirect is too slow")
        return False

def test_concurrent_requests() -> bool:
    """Test performance under concurrent load"""
    print(f"\n🔍 Testing concurrent request handling...")

    import concurrent.futures

    def make_request():
        try:
            req = urllib.request.Request("http://localhost:48580")
            req.add_header('Host', 'press.localhost')
            response = urllib.request.urlopen(req, timeout=10)
            return response.status == 200
        except:
            return False

    # Test with 10 concurrent requests
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        start = time.time()
        futures = [executor.submit(make_request) for _ in range(10)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]
        end = time.time()

    success_rate = sum(results) / len(results) * 100
    total_time = (end - start) * 1000

    print(f"  Concurrent requests: 10")
    print(f"  Success rate: {success_rate:.1f}%")
    print(f"  Total time: {total_time:.2f}ms")
    print(f"  Avg per request: {total_time/10:.2f}ms")

    if success_rate >= 90:
        print(f"  {Colors.GREEN}✓{Colors.RESET} Handles concurrent load well")
        return True
    else:
        print(f"  {Colors.RED}✗{Colors.RESET} Poor concurrent performance")
        return False

def test_static_resource_caching() -> bool:
    """Test static resource caching headers"""
    print(f"\n🔍 Testing static resource caching...")

    try:
        req = urllib.request.Request("http://localhost:48580")
        req.add_header('Host', 'press.localhost')
        response = urllib.request.urlopen(req, timeout=10)

        headers = dict(response.headers)

        # Check for caching headers
        has_cache_control = 'Cache-Control' in headers
        has_etag = 'ETag' in headers

        if has_cache_control or has_etag:
            print(f"  {Colors.GREEN}✓{Colors.RESET} Caching headers present")
            if has_cache_control:
                print(f"    Cache-Control: {headers['Cache-Control']}")
            if has_etag:
                print(f"    ETag: {headers['ETag'][:30]}...")
            return True
        else:
            print(f"  {Colors.YELLOW}⚠{Colors.RESET} No caching headers (may impact performance)")
            return True  # Warning only

    except Exception as e:
        print(f"  {Colors.RED}✗{Colors.RESET} Error testing caching: {str(e)}")
        return False

def main():
    """Run all performance tests"""
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BLUE}Press SaaS Platform - Performance Tests{Colors.RESET}")
    print(f"{Colors.BLUE}{'='*60}{Colors.RESET}")

    tests_passed = []
    tests_failed = []

    # Test 1: HTTP Response Time
    print(f"\n{Colors.YELLOW}Test Suite 1: Response Time{Colors.RESET}")
    if test_http_response_time():
        tests_passed.append("HTTP response time")
    else:
        tests_failed.append("HTTP response time")

    # Test 2: Redirect Performance
    print(f"\n{Colors.YELLOW}Test Suite 2: Redirect Performance{Colors.RESET}")
    if test_redirect_performance():
        tests_passed.append("Redirect performance")
    else:
        tests_failed.append("Redirect performance")

    # Test 3: Concurrent Requests
    print(f"\n{Colors.YELLOW}Test Suite 3: Concurrent Load{Colors.RESET}")
    if test_concurrent_requests():
        tests_passed.append("Concurrent load handling")
    else:
        tests_failed.append("Concurrent load handling")

    # Test 4: Caching
    print(f"\n{Colors.YELLOW}Test Suite 4: Caching{Colors.RESET}")
    if test_static_resource_caching():
        tests_passed.append("Static resource caching")
    else:
        tests_failed.append("Static resource caching")

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
        print(f"\n{Colors.GREEN}🎉 All performance tests passed!{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
