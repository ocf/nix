import os
import subprocess
import sys
from pprint import pprint
from urllib.parse import urlparse

import ocflib.printing.quota as quota
from ocflib.printing.printers import COLOR_PRINTERS
from utils import *


def main():
    if len(sys.argv) == 1:
        sys.exit(CUPS_BACKEND_OK)

    if len(sys.argv) != 7:
        print(
            f"Usage: {sys.argv[0]} job-id user title copies options [file]",
            file=sys.stderr,
        )
        sys.exit(CUPS_BACKEND_CANCEL)

    # we don't use copies (sys.argv[4])
    job_id, user, title, _, options, data_file = sys.argv[1:7]

    device_uri = os.environ.get("DEVICE_URI", "")
    printer_name = os.environ.get("PRINTER", "")
    class_name = os.environ.get("CLASS", printer_name)
    content_type = os.environ.get("CONTENT_TYPE", "")
    cups_serverbin = os.environ.get("CUPS_SERVERBIN", "/usr/lib/cups")

    with open(MYSQL_PASSWORD_FILE) as f:
        mysql_pass = f.read().strip()
    with open(WAYOUT_PASSWORD_FILE) as f:
        wayout_pass = f.read().strip()

    if content_type != "application/vnd.cups-postscript":
        print(
            f"ocf-cups-backend: unexpected CONTENT_TYPE: {content_type!r}",
            file=sys.stderr,
        )
        cancel_job(wayout_pass, Job(user=user), None, ENFORCER_ERROR)

    if not device_uri.startswith("ocfbackend:"):
        print(
            f"ocf-cups-backend: unexpected DEVICE_URI: {device_uri!r}",
            file=sys.stderr,
        )
        cancel_job(wayout_pass, Job(user=user), None, ENFORCER_ERROR)

    real_uri = device_uri[len("ocfbackend:") :]
    scheme = urlparse(real_uri).scheme
    # ipps uses the same backend binary as ipp
    backend_scheme = "ipp" if scheme == "ipps" else scheme
    backend_bin = os.path.join(cups_serverbin, "backend", backend_scheme)

    if not os.path.exists(backend_bin):
        print(
            f"ocf-cups-backend: backend not found: {backend_bin}",
            file=sys.stderr,
        )
        cancel_job(wayout_pass, Job(user=user), None, ENFORCER_ERROR)

    file_size = str(os.path.getsize(data_file))

    job = Job(
        id=int(job_id),
        user=user,
        document_title=title,
        printer_name=printer_name,
        class_name=class_name,
        data_file=data_file,
        job_size=file_size,
        time=datetime.now(),
    )

    job = job._replace(
        pages=page_count(job), hostname=get_hostname(job), page_size=page_size(job)
    )

    try:
        with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
            quo = quota.get_quota(c, job.user)

            # check quota before sending to printer
            if job.page_size not in LETTER_SIZES:
                cancel_job(wayout_pass, job, quo, NON_LETTER_ERROR)
            if job.pages > quo.daily:
                cancel_job(wayout_pass, job, quo, INSUFFICIENT_QUOTA)
            elif job.class_name in COLOR_PRINTERS and job.pages > quo.color:
                cancel_job(wayout_pass, job, quo, INSUFFICIENT_COLOR_QUOTA)

            # forward job to the real backend
            backend_env = dict(os.environ)
            backend_env["DEVICE_URI"] = real_uri

            # passing copies=1 to the backend, otherwise the backend
            # would re-apply copies, resulting in desiredCopies^2
            cmd = [backend_bin, job_id, user, title, "1", options, data_file]
            result = subprocess.run(cmd, env=backend_env, check=False)

            # log completed job to database
            if result.returncode == 0:
                add_db_job(c, job)
                notify_user(wayout_pass, job, None, JOB_QUEUED)
            else:
                quo = quota.get_quota(c, job.user)
                print(
                    f"""
                    enforcer encountered a printer error while processing a job, job details:
                    {pprint(job)}
                    """,
                    file=sys.stderr,
                )
                cancel_job(wayout_pass, job, quo, PRINTER_ERROR)

    except:
        print(
            f"""
            enforcer encountered an unknown error while processing a job, job details:
            {pprint(job)}
            """,
            file=sys.stderr,
        )
        cancel_job(wayout_pass, Job(user=user), None, ENFORCER_ERROR)


if __name__ == "__main__":
    main()
