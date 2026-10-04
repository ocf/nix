import re
import sys
from datetime import datetime
from syslog import syslog
from typing import NamedTuple

import cups
import ocflib.printing.quota as quota
import requests
from ocflib.misc.mail import send_mail_user

MYSQL_PASSWORD_FILE = "@mysqlPasswordFile@"
WAYOUT_PASSWORD_FILE = "@wayoutPasswordFile@"

# CUPS backend exit codes
CUPS_BACKEND_OK = 0
CUPS_BACKEND_FAILED = 1  # retry job
CUPS_BACKEND_CANCEL = 5  # cancel job, don't retry

WAYOUT_APP_NAME = "Printer"
WAYOUT_PORT = 6767

LETTER_SIZES = {"Letter", "279x215mm", "215x279mm", "279x216mm", "216x279mm"}


class Job(NamedTuple):
    id: int
    user: str
    document_title: str
    printer_name: str
    class_name: str
    data_file: str
    job_size: str
    time: datetime
    pages: int = 0
    hostname: str = ""
    page_size: str = ""


def page_count(job: Job):
    """Read the page count and copies from PostScript %%Pages: and %RBINumCopies: comments."""
    pages = 0
    copies = 1

    try:
        with open(job.data_file, "rb") as f:
            for line in f:
                if b"%%Pages:" in line or b"%RBINumCopies:" in line:
                    line_str = line.decode("utf-8", errors="ignore").strip()

                    pages_match = re.search(r"^%%Pages:\s+(\d+)", line_str)
                    if pages_match:
                        try:
                            pages = int(pages_match.group(1))
                        except ValueError:
                            syslog(
                                f"non-integer output when processing PS pages: {pages_match}"
                            )
                            pass

                    # always use PostScript copies
                    copies_match = re.search(r"^%RBINumCopies:\s+(\d+)", line_str)
                    if copies_match:
                        try:
                            copies = int(copies_match.group(1))
                        except ValueError:
                            syslog(
                                f"non-integer output when processing PS copies: {copies_match}"
                            )
                            pass
    except Exception as e:
        syslog(f"Page count error: {e}")
        pass

    total_sides = pages * copies
    if total_sides <= 0:
        syslog(f"failed to get document sides (pages={pages}, copies={copies})")
        sys.exit(CUPS_BACKEND_CANCEL)
    return total_sides


def page_size(job: Job):
    """Read the page size from PostScript %%PageMedia: or %%DocumentMedia: comments."""
    path = job.data_file
    with open(path, "rb") as f:
        header_chunk = f.read(4096)
    if b"%!" not in header_chunk:
        return None
    with open(path, "r", errors="ignore") as f:
        lines = f.readlines()
    candidates = lines[:20] + lines[-20:]
    for line in candidates:
        if line.startswith("%%PageMedia:"):
            return line.split()[1] if len(line.split()) > 1 else None
        if line.startswith("%%DocumentMedia:"):
            return line.split()[1] if len(line.split()) > 1 else None
    return None


def send_printer_mail(message: Message, job: Job, quo):
    body = message.body.format(
        user=job.user,
        time=job.time,
        doc_name=job.document_title,
        pages=job.pages,
        daily_pages=quo.daily,
        semester_pages=quo.semesterly,
        color_pages=quo.color,
        daily_quota=quota.daily_quota(),
        semester_quota=quota.SEMESTERLY_QUOTA,
        color_quota=quota.COLOR_QUOTA,
    )
    send_mail_user(job.user, message.subject, body)


def get_hostname(job: Job):
    conn = cups.Connection()
    job_attrs = conn.getJobAttributes(
        job.id, requested_attributes=["job-originating-host-name"]
    )
    return job_attrs.get("job-originating-host-name")


def send_notification(wayout_pass, job: Job, summary, body):
    try:
        if job.hostname == "":
            syslog(f"ERROR: no hostname found for job id: {job.id}")
            return
        url = "http://" + job.hostname + ":" + str(WAYOUT_PORT) + "/notify"
        data = {
            "summary": summary,
            "body": body,
            "app_name": WAYOUT_APP_NAME,
        }
        headers = {"Authorization": wayout_pass, "Content-Type": "application/json"}
        _ = requests.post(url=url, json=data, headers=headers, timeout=5)
    except Exception as e:
        syslog("Exception: " + str(e))
