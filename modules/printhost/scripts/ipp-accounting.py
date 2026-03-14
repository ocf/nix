#!/usr/bin/env python3
"""
IPP-completion accounting worker.

This replaces backend-hook accounting by polling completed CUPS jobs and
recording quota usage via ocflib.printing.quota.add_job.
"""

import os
import sys
from datetime import datetime
from urllib.parse import urlparse

import cups
import ocflib.printing.quota as quota
import requests

ABORTED_STATE = 8
CANCELED_STATE = 7
COMPLETED_STATE = 9
WAYOUT_APP_NAME = "Printer"
WAYOUT_PORT = 6767


def _scalar(value):
    if isinstance(value, (list, tuple)):
        value = value[0] if value else None
    if isinstance(value, bytes):
        value = value.decode("utf-8", errors="replace")
    return value


def _to_int(value, default=None):
    value = _scalar(value)
    try:
        return int(value) if value is not None else default
    except (TypeError, ValueError):
        return default


def _queue_from_uri(uri):
    uri = _scalar(uri) or ""
    path = urlparse(uri).path.strip("/")
    if path.startswith("classes/"):
        return path.split("/", 1)[1]
    if path.startswith("printers/"):
        return path.split("/", 1)[1]
    return path


def _pages_from_attrs(attrs):
    # Prefer sheets completed for paper accounting; fall back to impressions.
    sheets = _to_int(attrs.get("job-media-sheets-completed"), 0)
    impressions = _to_int(attrs.get("job-impressions-completed"), 0)
    copies = max(1, _to_int(attrs.get("copies"), 1))
    return max(sheets, impressions, copies, 1)


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
    with open(os.environ["ENFORCER_MYSQL_PASSWORD"]) as f:
        mysql_pass = f.read().strip()
    wayout_pass = ""
    if "ENFORCER_WAYOUT_PASSWORD" in os.environ:
        with open(os.environ["ENFORCER_WAYOUT_PASSWORD"]) as f:
            wayout_pass = f.read().strip()
    conn = cups.Connection()

    with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
        _ensure_hold_schema(c)
        c.execute(
            """
            SELECT `job_id`, `user`, `pages`, `queue`
            FROM `job_holds`
            WHERE `state` = 'active'
            ORDER BY `id` ASC
            """
        )
        active_holds = c.fetchall() or []

        for hold in active_holds:
            hold_id = _scalar(hold.get("job_id"))
            cups_job_id = _to_int(hold_id)
            if cups_job_id is None:
                continue

            try:
                attrs = conn.getJobAttributes(cups_job_id)
            except cups.IPPError:
                continue

            job_state = _to_int(attrs.get("job-state"), 0)
            if job_state == COMPLETED_STATE:
                user = _scalar(attrs.get("job-originating-user-name")) or _scalar(hold.get("user")) or ""
                if not user:
                    quota.settle_hold(c, hold_id)
                    continue

                printer_uri = _scalar(attrs.get("job-printer-uri")) or ""
                queue_name = _queue_from_uri(printer_uri) or _scalar(hold.get("queue")) or ""
                held_pages = _to_int(hold.get("pages"), 1) or 1
                pages = max(_pages_from_attrs(attrs), held_pages, 1)
                time_completed = _to_int(attrs.get("time-at-completed"))
                job_time = (
                    datetime.fromtimestamp(time_completed)
                    if time_completed
                    else datetime.now()
                )

                job = quota.Job(
                    user=user,
                    time=job_time,
                    pages=pages,
                    queue=queue_name,
                    printer=queue_name,
                    doc_name=_scalar(attrs.get("job-name")) or "",
                    filesize=str(max(0, _to_int(attrs.get("job-k-octets"), 0) * 1024)),
                )
                quota.add_job(c, job)
                quota.settle_hold(c, hold_id)
                _send_notification(
                    wayout_pass,
                    "Printer Success",
                    f"Your print job '{job.doc_name}' completed on {queue_name}.",
                    user,
                )
            elif job_state in {ABORTED_STATE, CANCELED_STATE}:
                quota.release_hold(c, hold_id)

    return 0


if __name__ == "__main__":
    sys.exit(main())
