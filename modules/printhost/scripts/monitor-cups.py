#!/usr/bin/env python3
"""
Collects metrics from CUPS and writes them to a text file in the Prometheus
metrics format.
"""

import logging
import sys
import getpass
import os

import cups
from prometheus_client import CollectorRegistry
from prometheus_client import Gauge
from prometheus_client import write_to_textfile

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    stream=sys.stderr,
)


def main():
    if len(sys.argv) < 2:
        logging.error("usage: monitor-cups.py <output_file>")
        return 1

    logging.info(f"Starting monitor-cups run as user: {getpass.getuser()} (UID: {os.getuid()})")
    cups.setUser("root")
    logging.info(f"CUPS user set to: {cups.getUser()}")
    logging.info(f"Starting monitor-cups run, outputting to {sys.argv[1]}")
    registry = CollectorRegistry()

    classes = Gauge(
        'cups_class',
        'Existence of printer on CUPS class',
        ['class', 'printer'],
        registry=registry,
    )

    queue = Gauge(
        'cups_queue_total',
        'Size of job queue',
        ['hostname', 'state'],
        registry=registry,
    )

    conn = cups.Connection()
    classes_count = 0
    for cups_class, printers in conn.getClasses().items():
        for printer in printers:
            # class is a reserved keyword, so we have to pass it via dictionary
            classes.labels(**{'class': cups_class, 'printer': printer}).set(1)
            classes_count += 1
    logging.info(f"Collected {classes_count} class-printer mappings")

    jobs_count = 0
    for job_id in conn.getJobs():
        try:
            job_attrs = conn.getJobAttributes(job_id)
            queue.labels(
                hostname=job_attrs['job-originating-host-name'],
                state=job_attrs['job-state'],
            ).inc()
            jobs_count += 1
        except cups.IPPError:
            pass
    logging.info(f"Collected metrics for {jobs_count} active jobs")

    write_to_textfile(sys.argv[1], registry)
    logging.info("finishing monitor-cups run")
    return 0

if __name__ == '__main__':
    sys.exit(main())
