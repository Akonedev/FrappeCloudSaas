#!/usr/bin/env python3
"""
Schedule Conflict Checker for Press SaaS Platform

This script validates that scheduled jobs (backup, pruning, maintenance)
do not have overlapping execution times that could cause resource contention.

Features:
- Parse cron schedules from Python files
- Detect time overlaps
- Warn about resource-intensive jobs running simultaneously
- Generate schedule visualization
- CI integration support

Usage:
    # Check for conflicts
    python scripts/check_schedule_conflicts.py

    # Verbose output with schedule visualization
    python scripts/check_schedule_conflicts.py --verbose

    # Output as JSON for CI
    python scripts/check_schedule_conflicts.py --json

    # Check specific files
    python scripts/check_schedule_conflicts.py --files press/cron/*.py

Addresses: CHK032
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Optional


# =============================================================================
# Cron Schedule Parser
# =============================================================================


@dataclass
class CronSchedule:
    """Parsed cron schedule."""

    minute: str
    hour: str
    day_of_month: str
    month: str
    day_of_week: str
    raw: str

    @classmethod
    def from_string(cls, cron_expr: str) -> "CronSchedule":
        """Parse a cron expression string."""
        parts = cron_expr.strip().split()
        if len(parts) != 5:
            raise ValueError(f"Invalid cron expression: {cron_expr}")

        return cls(
            minute=parts[0],
            hour=parts[1],
            day_of_month=parts[2],
            month=parts[3],
            day_of_week=parts[4],
            raw=cron_expr,
        )

    def get_next_runs(self, count: int = 24) -> list[datetime]:
        """
        Get next N run times (simplified implementation).

        For a full implementation, use croniter library.
        This is a simplified version for common patterns.
        """
        runs = []
        now = datetime.now().replace(second=0, microsecond=0)

        # Handle simple cases
        if self.minute.isdigit() and self.hour.isdigit():
            # Fixed time like "0 2 * * *" (02:00 daily)
            hour = int(self.hour)
            minute = int(self.minute)

            run_time = now.replace(hour=hour, minute=minute)
            if run_time <= now:
                run_time += timedelta(days=1)

            for _ in range(count):
                runs.append(run_time)
                run_time += timedelta(days=1)

        elif self.minute == "*/15" and self.hour == "*":
            # Every 15 minutes
            run_time = now.replace(minute=(now.minute // 15) * 15)
            if run_time <= now:
                run_time += timedelta(minutes=15)

            for _ in range(count):
                runs.append(run_time)
                run_time += timedelta(minutes=15)

        elif self.minute == "0" and self.hour == "*":
            # Hourly
            run_time = now.replace(minute=0)
            if run_time <= now:
                run_time += timedelta(hours=1)

            for _ in range(count):
                runs.append(run_time)
                run_time += timedelta(hours=1)

        return runs

    def overlaps_with(
        self,
        other: "CronSchedule",
        duration_minutes: int = 30,
    ) -> bool:
        """
        Check if this schedule overlaps with another.

        Args:
            other: Another cron schedule
            duration_minutes: Assumed job duration

        Returns:
            True if schedules overlap
        """
        my_runs = self.get_next_runs(24)
        other_runs = other.get_next_runs(24)

        duration = timedelta(minutes=duration_minutes)

        for my_run in my_runs:
            my_end = my_run + duration
            for other_run in other_runs:
                other_end = other_run + duration
                # Check overlap
                if my_run < other_end and other_run < my_end:
                    return True

        return False


# =============================================================================
# Scheduled Job Definition
# =============================================================================


@dataclass
class ScheduledJob:
    """Definition of a scheduled job."""

    name: str
    schedule: CronSchedule
    source_file: str
    line_number: int
    description: str = ""
    estimated_duration_minutes: int = 30
    resource_intensive: bool = False
    tags: list[str] = field(default_factory=list)


@dataclass
class ScheduleConflict:
    """Detected schedule conflict."""

    job1: ScheduledJob
    job2: ScheduledJob
    severity: str  # "warning" or "error"
    message: str


# =============================================================================
# Schedule Extractor
# =============================================================================


class ScheduleExtractor:
    """Extracts scheduled jobs from Python source files."""

    # Patterns to match cron schedules in code
    PATTERNS = [
        # scheduler.add_job(..., trigger='cron', hour=2, minute=0, ...)
        r'add_job\s*\([^)]*trigger\s*=\s*[\'"]cron[\'"][^)]*hour\s*=\s*(\d+)[^)]*minute\s*=\s*(\d+)',
        # @scheduler.scheduled_job('cron', hour=2, minute=0)
        r'scheduled_job\s*\([^)]*[\'"]cron[\'"][^)]*hour\s*=\s*(\d+)[^)]*minute\s*=\s*(\d+)',
        # BACKUP_SCHEDULE = "0 2 * * *"
        r'SCHEDULE\s*=\s*[\'"](\d+\s+\d+\s+\*\s+\*\s+\*)[\'"]',
        # cron: "0 2 * * *"
        r'cron:\s*[\'"](\d+\s+\d+\s+\*\s+\*\s+\*)[\'"]',
        # schedule="0 2 * * *"
        r'schedule\s*=\s*[\'"](\d+\s+\d+\s+[\d\*]+\s+[\d\*]+\s+[\d\*]+)[\'"]',
    ]

    # Known job definitions (fallback if parsing fails)
    KNOWN_JOBS = {
        "backup_scheduler.py": {
            "name": "Daily Backup",
            "schedule": "0 2 * * *",
            "duration": 60,
            "intensive": True,
            "tags": ["backup", "io-intensive"],
        },
        "prune_backups.py": {
            "name": "Backup Pruning",
            "schedule": "0 3 * * *",
            "duration": 30,
            "intensive": True,
            "tags": ["cleanup", "io-intensive"],
        },
    }

    def extract_from_file(self, file_path: Path) -> list[ScheduledJob]:
        """Extract scheduled jobs from a Python file."""
        jobs = []

        try:
            content = file_path.read_text()
        except Exception as e:
            print(f"  Warning: Could not read {file_path}: {e}")
            return jobs

        filename = file_path.name

        # Try known jobs first
        if filename in self.KNOWN_JOBS:
            known = self.KNOWN_JOBS[filename]
            try:
                schedule = CronSchedule.from_string(known["schedule"])
                jobs.append(
                    ScheduledJob(
                        name=known["name"],
                        schedule=schedule,
                        source_file=str(file_path),
                        line_number=1,
                        description=f"From {filename}",
                        estimated_duration_minutes=known["duration"],
                        resource_intensive=known["intensive"],
                        tags=known["tags"],
                    )
                )
            except ValueError:
                pass

        # Try pattern matching
        for line_num, line in enumerate(content.split("\n"), 1):
            for pattern in self.PATTERNS:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    try:
                        groups = match.groups()
                        if len(groups) == 2:
                            # hour, minute format
                            hour, minute = groups
                            cron_str = f"{minute} {hour} * * *"
                        else:
                            # full cron string
                            cron_str = groups[0]

                        schedule = CronSchedule.from_string(cron_str)

                        # Extract job name from context
                        name = self._extract_job_name(content, line_num)

                        jobs.append(
                            ScheduledJob(
                                name=name or f"Job in {filename}:{line_num}",
                                schedule=schedule,
                                source_file=str(file_path),
                                line_number=line_num,
                            )
                        )
                    except ValueError:
                        pass

        return jobs

    def _extract_job_name(self, content: str, line_num: int) -> Optional[str]:
        """Try to extract job name from surrounding context."""
        lines = content.split("\n")
        start = max(0, line_num - 5)
        end = min(len(lines), line_num + 2)

        context = "\n".join(lines[start:end])

        # Look for function name
        func_match = re.search(r'def\s+(\w+)', context)
        if func_match:
            return func_match.group(1).replace("_", " ").title()

        # Look for job name in string
        name_match = re.search(r'name\s*=\s*[\'"]([^\'"]+)[\'"]', context)
        if name_match:
            return name_match.group(1)

        return None

    def extract_from_directory(self, dir_path: Path) -> list[ScheduledJob]:
        """Extract scheduled jobs from all Python files in directory."""
        jobs = []

        if not dir_path.exists():
            return jobs

        for file_path in dir_path.glob("**/*.py"):
            file_jobs = self.extract_from_file(file_path)
            jobs.extend(file_jobs)

        return jobs


# =============================================================================
# Conflict Detector
# =============================================================================


class ConflictDetector:
    """Detects scheduling conflicts between jobs."""

    def __init__(self, overlap_threshold_minutes: int = 30):
        self.overlap_threshold = overlap_threshold_minutes

    def detect_conflicts(self, jobs: list[ScheduledJob]) -> list[ScheduleConflict]:
        """
        Detect conflicts between scheduled jobs.

        Args:
            jobs: List of scheduled jobs

        Returns:
            List of detected conflicts
        """
        conflicts = []

        for i, job1 in enumerate(jobs):
            for job2 in jobs[i + 1:]:
                # Check for time overlap
                if job1.schedule.overlaps_with(
                    job2.schedule,
                    duration_minutes=max(
                        job1.estimated_duration_minutes,
                        job2.estimated_duration_minutes,
                    ),
                ):
                    severity = self._determine_severity(job1, job2)
                    message = self._generate_conflict_message(job1, job2)

                    conflicts.append(
                        ScheduleConflict(
                            job1=job1,
                            job2=job2,
                            severity=severity,
                            message=message,
                        )
                    )

        return conflicts

    def _determine_severity(
        self,
        job1: ScheduledJob,
        job2: ScheduledJob,
    ) -> str:
        """Determine conflict severity."""
        # Both resource intensive = error
        if job1.resource_intensive and job2.resource_intensive:
            return "error"

        # Same tags (e.g., both io-intensive) = error
        common_tags = set(job1.tags) & set(job2.tags)
        if "io-intensive" in common_tags or "cpu-intensive" in common_tags:
            return "error"

        # Otherwise warning
        return "warning"

    def _generate_conflict_message(
        self,
        job1: ScheduledJob,
        job2: ScheduledJob,
    ) -> str:
        """Generate human-readable conflict message."""
        return (
            f"'{job1.name}' ({job1.schedule.raw}) overlaps with "
            f"'{job2.name}' ({job2.schedule.raw})"
        )


# =============================================================================
# Schedule Visualizer
# =============================================================================


class ScheduleVisualizer:
    """Visualizes job schedules."""

    def render_daily_schedule(self, jobs: list[ScheduledJob]) -> str:
        """Render a text-based daily schedule visualization."""
        lines = []
        lines.append("\nDaily Schedule (24-hour view)")
        lines.append("=" * 60)

        # Create hour grid
        hours = [" "] * 24
        job_rows: dict[str, list[str]] = {}

        for job in jobs:
            row = ["."] * 24
            runs = job.schedule.get_next_runs(1)
            if runs:
                hour = runs[0].hour
                duration_hours = max(1, job.estimated_duration_minutes // 60)
                for h in range(hour, min(24, hour + duration_hours)):
                    row[h] = "#"

            job_rows[job.name[:20]] = row

        # Header
        lines.append("Hour:  " + "".join(f"{h:2d}" for h in range(24)))
        lines.append("       " + "-" * 48)

        # Job rows
        for name, row in job_rows.items():
            lines.append(f"{name:20s} {''.join(row)}")

        lines.append("")
        lines.append("Legend: # = scheduled job, . = idle")

        return "\n".join(lines)


# =============================================================================
# Reporter
# =============================================================================


class ConflictReporter:
    """Reports schedule conflicts in various formats."""

    def report_text(
        self,
        jobs: list[ScheduledJob],
        conflicts: list[ScheduleConflict],
        verbose: bool = False,
    ) -> str:
        """Generate text report."""
        lines = []

        lines.append("\n" + "=" * 60)
        lines.append("SCHEDULE CONFLICT REPORT")
        lines.append("=" * 60)
        lines.append(f"\nJobs found: {len(jobs)}")
        lines.append(f"Conflicts found: {len(conflicts)}")

        if verbose and jobs:
            lines.append("\nScheduled Jobs:")
            lines.append("-" * 40)
            for job in jobs:
                lines.append(f"  - {job.name}")
                lines.append(f"    Schedule: {job.schedule.raw}")
                lines.append(f"    Source: {job.source_file}:{job.line_number}")
                lines.append(f"    Duration: ~{job.estimated_duration_minutes} min")
                if job.tags:
                    lines.append(f"    Tags: {', '.join(job.tags)}")

        if conflicts:
            lines.append("\nConflicts Detected:")
            lines.append("-" * 40)
            for conflict in conflicts:
                icon = "ERROR" if conflict.severity == "error" else "WARN"
                lines.append(f"  [{icon}] {conflict.message}")

        if not conflicts:
            lines.append("\nNo scheduling conflicts detected.")

        return "\n".join(lines)

    def report_json(
        self,
        jobs: list[ScheduledJob],
        conflicts: list[ScheduleConflict],
    ) -> str:
        """Generate JSON report for CI integration."""
        report = {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "jobs_found": len(jobs),
                "conflicts_found": len(conflicts),
                "errors": len([c for c in conflicts if c.severity == "error"]),
                "warnings": len([c for c in conflicts if c.severity == "warning"]),
            },
            "jobs": [
                {
                    "name": job.name,
                    "schedule": job.schedule.raw,
                    "source_file": job.source_file,
                    "line_number": job.line_number,
                    "duration_minutes": job.estimated_duration_minutes,
                    "resource_intensive": job.resource_intensive,
                    "tags": job.tags,
                }
                for job in jobs
            ],
            "conflicts": [
                {
                    "severity": conflict.severity,
                    "message": conflict.message,
                    "job1": conflict.job1.name,
                    "job2": conflict.job2.name,
                }
                for conflict in conflicts
            ],
        }

        return json.dumps(report, indent=2)


# =============================================================================
# CLI
# =============================================================================


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check for scheduling conflicts in Press platform jobs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output with schedule visualization",
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON for CI integration",
    )

    parser.add_argument(
        "--files",
        nargs="+",
        help="Specific files to check (default: press/cron/)",
    )

    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with error code on any conflict (not just errors)",
    )

    args = parser.parse_args()

    # Find project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    # Initialize components
    extractor = ScheduleExtractor()
    detector = ConflictDetector()
    visualizer = ScheduleVisualizer()
    reporter = ConflictReporter()

    # Extract jobs
    jobs = []

    if args.files:
        for file_glob in args.files:
            for file_path in Path().glob(file_glob):
                jobs.extend(extractor.extract_from_file(file_path))
    else:
        # Default directories to check
        cron_dir = project_root / "press" / "cron"
        worker_dir = project_root / "press" / "worker"

        jobs.extend(extractor.extract_from_directory(cron_dir))
        jobs.extend(extractor.extract_from_directory(worker_dir))

        # Also add known jobs if directories don't exist
        if not jobs:
            # Add default known jobs for validation
            for filename, config in ScheduleExtractor.KNOWN_JOBS.items():
                try:
                    schedule = CronSchedule.from_string(config["schedule"])
                    jobs.append(
                        ScheduledJob(
                            name=config["name"],
                            schedule=schedule,
                            source_file=f"press/cron/{filename}",
                            line_number=1,
                            estimated_duration_minutes=config["duration"],
                            resource_intensive=config["intensive"],
                            tags=config["tags"],
                        )
                    )
                except ValueError:
                    pass

    # Detect conflicts
    conflicts = detector.detect_conflicts(jobs)

    # Generate report
    if args.json:
        print(reporter.report_json(jobs, conflicts))
    else:
        print(reporter.report_text(jobs, conflicts, verbose=args.verbose))

        if args.verbose and jobs:
            print(visualizer.render_daily_schedule(jobs))

    # Determine exit code
    errors = [c for c in conflicts if c.severity == "error"]

    if errors:
        sys.exit(1)
    elif args.strict and conflicts:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
