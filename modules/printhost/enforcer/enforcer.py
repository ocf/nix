import os
import subprocess
import sys
import threading
import time
from pprint import pprint
from syslog import syslog
from urllib.parse import urlparse

import cups
import ocflib.printing.quota as quota
from ocflib.printing.printers import COLOR_PRINTERS
from utils import *

MAX_RETRIES = 3
DELAY = 10


# needs a retry mechanism as the job data file may not exist yet when the job is created
def enforce_print_init(job_data, job: Job):
    attempt = 0
    success = False
    
    conn = cups.Connection()
    with open(MYSQL_PASSWORD_FILE) as f:
        mysql_pass = f.read().strip()
    with open(WAYOUT_PASSWORD_FILE) as f:
        wayout_pass = f.read().strip()


    while attempt < MAX_RETRIES and not success:
        try:
            syslog(f"job {job.id}: attempt {attempt + 1}...")

            enforce_print(conn, mysql_pass, wayout_pass, job_data, job)

            syslog(f"job {job.id}: enforcer succeeded")
            success = True

        except cups.IPPError as e:
            attempt += 1
            syslog(f"job {job.id}: error = {e}. retrying in {DELAY} seconds...")
            time.sleep(DELAY)

    if not success:
        syslog(f"job {job.id}: max retries reached")
        cancel_job(conn, wayout_pass, job, None, ENFORCER_ERROR)


def enforce_print(conn, mysql_pass, wayout_pass, job_data, job: Job):
    # get file details
    document = conn.getDocument(job.printer_uri, job.id, 1)
    data_file = document.get("file")
    type = document.get("document-format")
    assert type == "application/pdf"  # must be pdf
    file_size = str(os.path.getsize(data_file))
    job = job._replace(
        data_file=data_file,
        job_size=file_size,
    )

    job = job._replace(
        pages=page_count(job),
        # page_size=page_size(job),
    )

    with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
        quo = quota.get_quota(c, job.user)

        # check quota before sending to printer
        # if job.page_size not in LETTER_SIZES: # TODO fix page size check
        #     cancel_job(conn, wayout_pass, job, quo, NON_LETTER_ERROR)
        if job.pages > quo.daily:
            cancel_job(conn, wayout_pass, job, quo, INSUFFICIENT_QUOTA)
        elif job.printer_name in COLOR_PRINTERS and job.pages > quo.color:
            cancel_job(conn, wayout_pass, job, quo, INSUFFICIENT_COLOR_QUOTA)

        # release job
        syslog(f"job {job.id}: released")
        conn.setJobHoldUntil(job.id, "no-hold")
        save_pending_job_data(job_data, job)


def post_print(job_data, job: Job):
    with open(MYSQL_PASSWORD_FILE) as f:
        mysql_pass = f.read().strip()
    with open(WAYOUT_PASSWORD_FILE) as f:
        wayout_pass = f.read().strip()

    job = get_pending_job_data(job_data, job)

    with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
        add_db_job(c, job)
    notify_user(wayout_pass, job, None, JOB_QUEUED)
