#!/usr/bin/env python3
"""
Phase 2 submit-time quota gate (dev path).

Inspects pending CUPS jobs and cancels quickly when user credit is insufficient.
This is transport/driver agnostic and works with driverless IPP queues.
"""

import logging
import os
import re
import subprocess
import sys
import getpass
from datetime import datetime
from urllib.parse import urlparse

import cups
import ocflib.printing.quota as quota
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    stream=sys.stderr,
)

COLOR_QUEUES = {"color-single", "color-double"}
PENDING_STATE = 3
HELD_STATE = 4
WAYOUT_APP_NAME = "Printer"
WAYOUT_PORT = 6767


def _scalar(value):
    if isinstance(value, (list, tuple)):
        return value[0] if value else None
    return value


def _to_int(value, default=0):
    try:
        v = _scalar(value)
        return int(v) if v is not None else default
    except (TypeError, ValueError):
        return default


def _queue_from_uri(uri):
    uri = _scalar(uri) or ""
    path = urlparse(uri).path.strip("/")
    if "/" in path:
        prefix, name = path.split("/", 1)
        if prefix in ("classes", "printers"):
            return name
    return path


def _get_pdf_pages(job_id):
    # CUPS spool files are usually in /var/spool/cups/dXXXXX-001
    spool_path = f"/var/spool/cups/d{job_id:05d}-001"
    if not os.path.exists(spool_path):
        logging.debug(f"Spool file {spool_path} not found for job {job_id}")
        return None
    
    try:
        # Use pdfinfo to get the actual page count from the spool file
        out = subprocess.check_output(["pdfinfo", spool_path], stderr=subprocess.STDOUT, text=True)
        for line in out.splitlines():
            if line.startswith("Pages:"):
                return int(line.split(":")[1].strip())
    except Exception as exc:
        logging.debug(f"pdfinfo failed for job {job_id}: {exc}")
    
    return None


def _estimate_requested_pages(attrs):
    job_id = _to_int(attrs.get("job-id"), 0)
    
    # Prefer IPP-reported impression/media estimates.
    # When a job is first submitted and held, these are often 0.
    impressions = _to_int(attrs.get("job-impressions"), 0)
    sheets = _to_int(attrs.get("job-media-sheets"), 0)
    
    # Check both standard and common variant for copies
    copies = max(
        1, 
        _to_int(attrs.get("copies"), 1), 
        _to_int(attrs.get("number-of-copies"), 1)
    )
    
    base_pages = max(impressions, sheets)
    
    # Fallback: if IPP counts are 0 and it's a PDF, try inspecting the spool file.
    if base_pages == 0 and attrs.get("document-format") == "application/pdf":
        pdf_pages = _get_pdf_pages(job_id)
        if pdf_pages is not None:
            logging.info(f"Discovered {pdf_pages} document pages via pdfinfo for job {job_id}")
            # pdfinfo gives pages in the doc, we MUST multiply by copies
            base_pages = pdf_pages
            
    # Final safety floor
    if base_pages == 0:
        base_pages = 1
        
    est = base_pages * copies
    logging.info(f"Page estimate for job {job_id}: base_pages={base_pages}, copies={copies} (from attrs: impressions={impressions}, sheets={sheets}) -> total={est}")
    return est


def _hold_id(job_id):
    return str(int(job_id))


def _active_hold_pages(c, hold_id):
    c.execute(
        "SELECT `pages` FROM `job_holds` WHERE `job_id` = %s AND `state` = 'active'",
        (hold_id,),
    )
    row = c.fetchone()
    return _to_int(row["pages"], 0) if row else 0


def _ensure_hold_schema(c):
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS `job_holds` (
            `id` bigint NOT NULL AUTO_INCREMENT,
            `job_id` varchar(255) NOT NULL,
            `user` varchar(255) NOT NULL,
            `time` datetime NOT NULL,
            `pages` int unsigned NOT NULL,
            `queue` varchar(255) NOT NULL,
            `state` enum('active', 'released', 'settled') NOT NULL DEFAULT 'active',
            PRIMARY KEY (`id`),
            UNIQUE KEY `job_holds_job_id_uniq` (`job_id`),
            KEY `job_holds_user_state_time_idx` (`user`, `state`, `time`)
        ) ENGINE=InnoDB
        """
    )


def _hold_job(conn, job_id):
    if hasattr(conn, "setJobHoldUntil"):
        conn.setJobHoldUntil(job_id, "indefinite")
        return
    if hasattr(conn, "holdJob"):
        conn.holdJob(job_id)
        return
    raise RuntimeError("No CUPS hold API available on this pycups build")


def _release_job(conn, job_id):
    if hasattr(conn, "setJobHoldUntil"):
        conn.setJobHoldUntil(job_id, "no-hold")
        return
    if hasattr(conn, "releaseJob"):
        conn.releaseJob(job_id)
        return
    raise RuntimeError("No CUPS release API available on this pycups build")


def _get_hostname_from_username(username):
    try:
        res = requests.get("https://labmap.ocf.berkeley.edu/api/generate", timeout=5).json()
        for desktop in res.get("desktops", []):
            if desktop.get("user", "") == username:
                return desktop.get("name")
    except Exception:
        return None
    return None


def _send_notification(wayout_pass, summary, body, username):
    if not wayout_pass:
        return
    try:
        hostname = _get_hostname_from_username(username)
        if not hostname:
            return
        url = f"http://{hostname}:{WAYOUT_PORT}/notify"
        requests.post(
            url=url,
            json={"summary": summary, "body": body, "app_name": WAYOUT_APP_NAME},
            headers={"Authorization": wayout_pass, "Content-Type": "application/json"},
            timeout=5,
        )
    except Exception:
        pass


def main():
    logging.info(f"Starting submit-gate run as user: {getpass.getuser()} (UID: {os.getuid()})")
    cups.setUser("root")
    logging.info(f"CUPS user set to: {cups.getUser()}")
    with open(os.environ["ENFORCER_MYSQL_PASSWORD"]) as f:
        mysql_pass = f.read().strip()
    wayout_pass = ""
    if "ENFORCER_WAYOUT_PASSWORD" in os.environ:
        with open(os.environ["ENFORCER_WAYOUT_PASSWORD"]) as f:
            wayout_pass = f.read().strip()
    try:
        conn = cups.Connection()
        logging.info(f"Connected to CUPS server: {cups.getServer()}")
    except RuntimeError as exc:
        logging.error(f"cups unavailable, skipping submit-gate run: {exc}")
        return 0

    # Diagnostic: check printers and classes
    try:
        printers = conn.getPrinters()
        classes = conn.getClasses()
        logging.info(f"CUPS has {len(printers)} printers and {len(classes)} classes")
        for name, attrs in printers.items():
            if isinstance(attrs, dict):
                count = _to_int(attrs.get("queued-job-count"), 0)
                if count > 0:
                    logging.info(f"Printer {name} reports {count} queued jobs")
        
        for name, members in classes.items():
            logging.info(f"Class {name} members: {members}")
            try:
                # To get attributes for a class, we use the same call as for a printer
                class_attrs = conn.getPrinterAttributes(name)
                count = _to_int(class_attrs.get("queued-job-count"), 0)
                if count > 0:
                    logging.info(f"Class {name} reports {count} queued jobs")
            except Exception:
                pass
    except Exception as exc:
        logging.error(f"failed to list printers/classes: {exc}")

    # Active/pending jobs only.
    jobs = {}
    try:
        # Try global first with standard filters
        for filter_name in ["not-completed", "all"]:
            try:
                res = conn.getJobs(which_jobs=filter_name, my_jobs=False)
                if res:
                    logging.info(f"Global getJobs('{filter_name}') found: {list(res.keys())}")
                    jobs.update(res)
            except Exception as exc:
                logging.warning(f"Global getJobs('{filter_name}') failed: {exc}")
        
        # If still empty, try checking each printer AND class specifically
        if not jobs:
            all_dests = list(printers.keys()) + list(classes.keys())
            logging.info(f"Checking {len(all_dests)} destinations specifically...")
            for name in all_dests:
                try:
                    res = conn.getJobs(name=name, which_jobs="not-completed", my_jobs=False)
                    if res:
                        logging.info(f"Found {len(res)} jobs specifically in '{name}': {list(res.keys())}")
                        jobs.update(res)
                except Exception:
                    pass

        # Fallback/Diagnostic: check lpstat via subprocess
        if not jobs:
            try:
                lpstat_out = subprocess.check_output(["lpstat", "-o"], stderr=subprocess.STDOUT, text=True)
                if lpstat_out.strip():
                    logging.info(f"lpstat -o output found jobs:\n{lpstat_out}")
                    # Extract job IDs from lpstat output (e.g., "double-2")
                    for line in lpstat_out.splitlines():
                        match = re.match(r'^(\S+)-(\d+)\s+', line)
                        if match:
                            dest, job_id_str = match.groups()
                            job_id = int(job_id_str)
                            logging.info(f"Attempting to inspect job {job_id} discovered via lpstat")
                            try:
                                attrs = conn.getJobAttributes(job_id)
                                jobs[job_id] = attrs
                            except Exception as exc:
                                logging.error(f"Failed to get attributes for discovered job {job_id}: {exc}")
            except Exception as exc:
                logging.debug(f"lpstat fallback failed: {exc}")

    except (cups.IPPError, RuntimeError) as exc:
        logging.error(f"major failure listing jobs: {exc}")
        return 0

    if jobs:
        logging.info(f"Found {len(jobs)} total jobs to process: {list(jobs.keys())}")
    else:
        logging.info("no active jobs found in CUPS (checked global, classes, and lpstat)")
        logging.info("finishing submit-gate run")
        return 0

    # Define attributes we need, but also request 'all' for discovery
    REQ_ATTRS = ["all"]

    with quota.get_connection(user="ocfprinting", password=mysql_pass) as qdb:
        _ensure_hold_schema(qdb)
        for job_id in sorted(jobs.keys()):
            try:
                attrs = conn.getJobAttributes(job_id, requested_attributes=REQ_ATTRS)
                logging.info(f"Inspecting job {job_id} attributes: {attrs}")
            except cups.IPPError:
                continue

            job_state = _to_int(attrs.get("job-state"), 0)
            if job_state not in {PENDING_STATE, HELD_STATE}:
                continue

            user = _scalar(attrs.get("job-originating-user-name")) or ""
            if not user:
                continue

            hold_id = _hold_id(job_id)
            queue = _queue_from_uri(attrs.get("job-printer-uri"))
            pages = _estimate_requested_pages(attrs)

            if job_state == PENDING_STATE:
                try:
                    logging.info(f"holding job {job_id} for user {user} on queue {queue}")
                    _hold_job(conn, job_id)
                except (cups.IPPError, RuntimeError) as exc:
                    logging.error(f"failed to hold job {job_id}: {exc}")
                continue

            held_pages = _active_hold_pages(qdb, hold_id)
            user_quota = quota.get_quota(qdb, user)

            available_daily = user_quota.daily + held_pages
            available_color = user_quota.color + held_pages
            over_daily = pages > available_daily
            over_color = queue in COLOR_QUEUES and pages > available_color
            if over_daily or over_color:
                # Reject before print path reaches backend when possible.
                logging.info(
                    f"canceling job {job_id}: user={user} queue={queue} pages={pages} "
                    f"daily_left={available_daily} color_left={available_color}",
                )
                try:
                    conn.cancelJob(job_id, purge_job=False)
                    if held_pages > 0:
                        quota.release_hold(qdb, hold_id)
                    _send_notification(
                        wayout_pass,
                        "Insufficient Quota",
                        f"Your print job was canceled because it exceeds your quota ({pages} pages).",
                        user,
                    )
                except cups.IPPError:
                    pass
                continue

            logging.info(f"releasing job {job_id} for user {user} on queue {queue}")
            quota.add_hold(
                qdb,
                quota.Hold(
                    job_id=hold_id,
                    user=user,
                    time=datetime.now(),
                    pages=pages,
                    queue=queue,
                ),
            )
            try:
                _release_job(conn, job_id)
            except (cups.IPPError, RuntimeError) as exc:
                logging.error(f"failed to release job {job_id}: {exc}")

    logging.info("finishing submit-gate run")
    return 0


if __name__ == "__main__":
    sys.exit(main())
