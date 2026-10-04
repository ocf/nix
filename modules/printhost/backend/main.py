import os
import subprocess
import sys
from pprint import pprint
from syslog import syslog
from urllib.parse import urlparse

import ocflib.printing.quota as quota
from ocflib.misc.mail import send_problem_report
from ocflib.printing.printers import COLOR_PRINTERS

from messages import *
from utils import *


def prehook(c, wayout_pass, job: Job):
    quo = quota.get_quota(c, job.user)

    if job.page_size not in LETTER_SIZES:
        send_printer_mail(NON_LETTER_ERROR_MESSAGE, job, quo)
        msg = NOTIFY_NON_LETTER.format(document=job.document_title)
        send_notification(wayout_pass, job, "Non Letter Error", msg)
        sys.exit(CUPS_BACKEND_CANCEL)

    if job.pages > quo.daily:
        send_printer_mail(INSUFFICIENT_QUOTA_MESSAGE, job, quo)
        msg = NOTIFY_QUOTA_MESSAGE.format(
            pages=job.pages,
            quota=quo.daily,
        )
        send_notification(wayout_pass, job, "Insufficient Quota", msg)
        sys.exit(CUPS_BACKEND_CANCEL)
    elif job.class_name in COLOR_PRINTERS and job.pages > quo.color:
        send_printer_mail(INSUFFICIENT_COLOR_QUOTA_MESSAGE, job, quo)
        msg = NOTIFY_COLOR_QUOTA_MESSAGE.format(
            pages=job.pages,
            quota=quo.color,
        )
        send_notification(wayout_pass, job, "Insufficient Color Quota", msg)
        sys.exit(CUPS_BACKEND_CANCEL)


def posthook(c, wayout_pass: str, job: Job, return_code: int):
    msg = ""
    if return_code == 0:
        quota.add_job(
            c,
            quota.Job(
                user=job.user,
                time=job.time,
                pages=job.pages,
                queue=job.class_name,
                printer=job.printer_name,
                doc_name=job.document_title,
                filesize=job.job_size,
            ),
        )
        msg = NOTIFY_JOB_QUEUED.format(
            document=job.document_title, printer=job.printer_name
        )
        send_notification(wayout_pass, job, "Job Queued", msg)
    else:
        quo = quota.get_quota(c, job.user)
        msg = NOTIFY_JOB_ERROR.format(document=job.document_title)
        send_printer_mail(PRINTER_ERROR_MESSAGE, job, quo)

        err_msg = dedent(f"""\
            enforcer encountered a printer error while processing a job

            job details:
            {pprint(job)}
            """)

        syslog(err_msg)
        send_problem_report(err_msg)
        send_notification(wayout_pass, job, "Printer Error", msg)
        sys.exit(CUPS_BACKEND_FAILED)


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

    if content_type != "application/vnd.cups-postscript":
        print(
            f"ocf-cups-backend: unexpected CONTENT_TYPE: {content_type!r}",
            file=sys.stderr,
        )
        sys.exit(CUPS_BACKEND_CANCEL)

    if not device_uri.startswith("ocfbackend:"):
        print(
            f"ocf-cups-backend: unexpected DEVICE_URI: {device_uri!r}",
            file=sys.stderr,
        )
        sys.exit(CUPS_BACKEND_CANCEL)

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
        sys.exit(CUPS_BACKEND_CANCEL)

    try:
        try:
            file_size = str(os.path.getsize(data_file))
        except OSError:
            file_size = "0"

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

        with open(MYSQL_PASSWORD_FILE) as f:
            mysql_pass = f.read().strip()
        with open(WAYOUT_PASSWORD_FILE) as f:
            wayout_pass = f.read().strip()

        with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
            # check quota before sending to printer
            prehook(c, wayout_pass, job)

            # forward job to the real backend
            backend_env = dict(os.environ)
            backend_env["DEVICE_URI"] = real_uri

            # passing copies=1 to the backend, otherwise the backend
            # would re-apply copies, resulting in desiredCopies^2
            # this is only an issue on the epson because the ocf-cups-backend
            # forwards directly to it rather than to a class and raw queue first
            cmd = [backend_bin, job_id, user, title, "1", options, data_file]
            result = subprocess.run(cmd, env=backend_env, check=False)

            # log completed job to database
            posthook(c, wayout_pass, job, result.returncode)

            sys.exit(result.returncode)

    finally:
        pass


if __name__ == "__main__":
    main()
