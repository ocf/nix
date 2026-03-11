#!/usr/bin/env python3
"""Enforcer is a backend for cups whose primary purpose is to
add and subtract from page quotas as user jobs are processed.

When a user sends a job to the print server, the enforcer backend passes the job
as a PostScript file to enforcer before sending it to the printer. Enforcer calls
reads PostScript comments to count pages and connects to mysql to check against
the user's quota. If enforcer returns 255 (a.k.a. -1), the job is rejected.
Otherwise, enforcer gets called again when the job is done and logs the job in
mysql, taking care to set the page count to zero if an error was encountered.

Another function of enforcer is to send notifications to desktops to let users
know when a job has been sent to the printer, been rejected due to the quota,
finished printing, or failed to print.
"""

import os
import subprocess
import sys
import tempfile
from datetime import datetime
from syslog import syslog
from textwrap import dedent
from traceback import format_exc

import ocflib.printing.quota as quota
import redis
import requests
from ocflib.misc.mail import MAIL_SIGNATURE, send_mail_user, send_problem_report

CUPS_BACKEND_OK = 0
CUPS_BACKEND_FAILED = 1
CUPS_BACKEND_CANCEL = 5

COLOR_QUEUE = "color-single"
WAYOUT_APP_NAME = "Printer"
WAYOUT_PORT = 6767

ENFORCER_PC = "@enforcerPc@"
ENFORCER_SIZE = "@enforcerSize@"
SOCKET_BACKEND = "@socketBackend@"
IPP_BACKEND = "@ippBackend@"


USER_ERROR_INFO = dedent("""\
    Username: {user}
    Time: {time}
    File: {doc_name}
    Total pages: {pages}
    Pages left today: {daily_pages}
    Pages left this semester: {semester_pages}
    Color pages left: {color_pages}\
""")

INSUFFICIENT_QUOTA_MESSAGE_SUBJECT = "[OCF] Your latest print job was rejected"
INSUFFICIENT_QUOTA_MESSAGE_BODY = (
    dedent("""\
    Greetings from the Open Computing Facility,

    This email is letting you know that your most recent print job was
    rejected since it would exceed your daily quota. The daily quota is
    {daily_quota} pages today and the semesterly quota is {semester_quota} pages.

    """)
    + USER_ERROR_INFO
    + dedent("""

    Does something look wrong? Please reply to

        help@ocf.berkeley.edu


    """)
    + MAIL_SIGNATURE
)

INSUFFICIENT_COLOR_QUOTA_MESSAGE_SUBJECT = "[OCF] Your latest print job was rejected"
INSUFFICIENT_COLOR_QUOTA_MESSAGE_BODY = (
    dedent("""\
    Greetings from the Open Computing Facility,

    This email is letting you know that your most recent print job was
    rejected since it would exceed your color printing quota. The color printing
    quota is {color_quota} pages and the semesterly quota is {semester_quota}
    pages.

    """)
    + USER_ERROR_INFO
    + dedent("""

    Does something look wrong? Please reply to

        help@ocf.berkeley.edu


    """)
    + MAIL_SIGNATURE
)

PRINTER_ERROR_MESSAGE_SUBJECT = "[OCF] Your latest print job failed"
PRINTER_ERROR_MESSAGE_BODY = (
    dedent("""\
    Greetings from the Open Computing Facility,

    This email is from the OCF to let you know that your most recent print
    job failed due to a printer error. If there's something wrong with the
    printers, please alert the operations staff at the desk.

    """)
    + USER_ERROR_INFO
    + dedent("""

    Still can't get it to print? Please reply to

        help@ocf.berkeley.edu


    """)
    + MAIL_SIGNATURE
)

ENFORCER_ERROR_MESSAGE_SUBJECT = "[OCF] Your latest print job failed"
ENFORCER_ERROR_MESSAGE_BODY = (
    dedent("""\
    Greetings from the Open Computing Facility,

    This email is from the OCF to let you know that your most recent print
    job failed due to a problem with the print accounting system. OCF staff
    have been notified of the problem and should fix it shortly. If there
    is a staff member in lab, you can ask them for help in the meantime.

    """)
    + USER_ERROR_INFO
    + dedent("""

    Still can't get it to print? Please reply to

        help@ocf.berkeley.edu


    """)
    + MAIL_SIGNATURE
)

NON_LETTER_ERROR_MESSAGE_SUBJECT = "[OCF] Your latest print job failed"
NON_LETTER_ERROR_MESSAGE_BODY = (
    dedent("""\
    Greetings from the Open Computing Facility,

    This email is letting you know that your most recent print job was
    rejected since it was not letter sized. Please ensure that you are
    following all instructions on the computers, and not printing
    directly from your browser.

    """)
    + USER_ERROR_INFO
    + dedent("""

    Does something look wrong? Please reply to

        help@ocf.berkeley.edu

    """)
    + MAIL_SIGNATURE
)

NOTIFY_QUOTA_MESSAGE = dedent("""\
        Your print job failed due to insufficient pages. Your job was
        {pages} pages, and you have {quota} pages remaining today.\
""")

NOTIFY_JOB_ACCEPTED = dedent("""\
        Your print job '{document}' was accepted and sent to {printer}.\
""")

NOTIFY_JOB_ERROR = dedent("""\
        Your print job '{document}' failed due to a printer error.
        Please contact a staff member for assistance.\
""")

NOTIFY_NON_LETTER = dedent("""\
        Your print job '{document}' failed due to not being letter sized.
        Please ensure you are not printing from your browser.
""")


def read_config():
    mysql_passwd = open(os.environ["ENFORCER_MYSQL_PASSWORD"]).read().strip()
    redis_host = os.environ["ENFORCER_REDIS_HOST"]
    redis_passwd = open(os.environ["ENFORCER_REDIS_PASSWORD"]).read().strip()
    wayout_passwd = open(os.environ["ENFORCER_WAYOUT_PASSWORD"]).read().strip()
    return mysql_passwd, redis_host, redis_passwd, wayout_passwd


def page_count(filepath, copies):
    out = subprocess.check_output((ENFORCER_PC, filepath), timeout=30).strip()
    if not out:
        raise ValueError(f"could not determine page count from {filepath!r} (no %%Pages DSC comment found)")
    return copies * int(out)


def page_size(filepath):
    return (
        subprocess.check_output(
            (ENFORCER_SIZE, filepath),
            timeout=30,
        )
        .decode("UTF-8")
        .strip()
    )


def get_job_and_filepath(argv):
    """Parse CUPS backend arguments and build a quota.Job."""
    username = argv[2]
    title = argv[3]
    copies = int(argv[4])

    if len(argv) > 6:
        filepath = argv[6]
        tmp_file = None
    else:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".ps")
        tmp.write(sys.stdin.buffer.read())
        tmp.close()
        filepath = tmp.name
        tmp_file = filepath

    printer = os.environ.get("PRINTER", "")
    queue = os.environ.get("CLASS", printer)
    filesize = os.path.getsize(filepath)

    job = quota.Job(
        user=username,
        time=datetime.now(),
        pages=page_count(filepath, copies),
        queue=queue,
        printer=printer,
        doc_name=title,
        filesize=str(filesize),
    )
    return job, filepath, tmp_file


def get_hostname_from_username(username):
    try:
        url = "https://labmap.ocf.berkeley.edu/api/generate"
        res = requests.get(url, timeout=5).json()
        for desktop in res.get("desktops", []):
            if desktop.get("user", "") == username:
                return desktop.get("name")
    except Exception as e:
        syslog("labmap lookup error: " + str(e))
    return None


def send_notification(wayout_pass, summary, body, username):
    try:
        hostname = get_hostname_from_username(username)
        if not hostname:
            return
        url = "http://" + hostname + ":" + str(WAYOUT_PORT) + "/notify"
        requests.post(
            url=url,
            json={"summary": summary, "body": body, "app_name": WAYOUT_APP_NAME},
            headers={"Authorization": wayout_pass, "Content-Type": "application/json"},
            timeout=5,
        )
    except Exception as e:
        syslog("send_notification error: " + str(e))


def send_printer_mail(subject, body_template, job, quo):
    body = body_template.format(
        user=job.user,
        time=job.time,
        doc_name=job.doc_name,
        pages=job.pages,
        daily_pages=quo.daily,
        semester_pages=quo.semesterly,
        color_pages=quo.color,
        daily_quota=quota.daily_quota(),
        semester_quota=quota.SEMESTERLY_QUOTA,
        color_quota=quota.COLOR_QUOTA,
    )
    send_mail_user(job.user, subject, body)


def do_prehook(c, r, job, filepath, wayout_pass):
    """Check quotas and page size. Returns (ok, quo); ok=False cancels the job."""
    quo = quota.get_quota(c, job.user)
    size = page_size(filepath)

    if size not in ["Letter", "279x215mm", "215x279mm", "279x216mm", "216x279mm"]:
        send_printer_mail(
            NON_LETTER_ERROR_MESSAGE_SUBJECT,
            NON_LETTER_ERROR_MESSAGE_BODY,
            job,
            quo,
        )
        msg = NOTIFY_NON_LETTER.format(document=job.doc_name)
        r.publish("user-" + job.user, msg)
        send_notification(wayout_pass, "Non Letter Error", msg, job.user)
        return False, quo

    if job.pages > quo.daily:
        send_printer_mail(
            INSUFFICIENT_QUOTA_MESSAGE_SUBJECT,
            INSUFFICIENT_QUOTA_MESSAGE_BODY,
            job,
            quo,
        )
        msg = NOTIFY_QUOTA_MESSAGE.format(pages=job.pages, quota=quo.daily)
        r.publish("user-" + job.user, msg)
        send_notification(wayout_pass, "Insufficient Quota", msg, job.user)
        return False, quo

    if job.queue == COLOR_QUEUE and job.pages > quo.color:
        send_printer_mail(
            INSUFFICIENT_COLOR_QUOTA_MESSAGE_SUBJECT,
            INSUFFICIENT_COLOR_QUOTA_MESSAGE_BODY,
            job,
            quo,
        )
        msg = NOTIFY_QUOTA_MESSAGE.format(pages=job.pages, quota=quo.color)
        r.publish("user-" + job.user, msg)
        send_notification(wayout_pass, "Insufficient Color Quota", msg, job.user)
        return False, quo

    return True, quo


def forward_to_printer(argv, filepath):
    """Delegate to the appropriate CUPS backend for actual printing.

    Device URIs use the format enforcer:socket://host:port or
    enforcer:ipp://host:port/path — the embedded scheme selects the backend.
    """
    device_uri = os.environ.get("DEVICE_URI", "")
    real_uri = device_uri.split(":", 1)[1]  # strip "enforcer:" prefix
    scheme = real_uri.split("://", 1)[0]
    backend = IPP_BACKEND if scheme == "ipp" else SOCKET_BACKEND
    env = {**os.environ, "DEVICE_URI": real_uri}
    result = subprocess.run(
        [backend] + argv[1:6] + [filepath],
        env=env,
        timeout=600,
    )
    return result.returncode == 0


def do_posthook(c, r, job, quo, success, wayout_pass):
    if success:
        quota.add_job(c, job)
        printer_name = job.printer.split("-")[0]
        msg = NOTIFY_JOB_ACCEPTED.format(
            document=job.doc_name,
            printer=printer_name,
        )
        r.publish("printer-" + printer_name, job.user)
        send_notification(wayout_pass, "Printer Success", msg, job.user)
    else:
        msg = NOTIFY_JOB_ERROR.format(document=job.doc_name)
        send_printer_mail(
            PRINTER_ERROR_MESSAGE_SUBJECT,
            PRINTER_ERROR_MESSAGE_BODY,
            job,
            quo,
        )
        err_msg = (
            "enforcer encountered a printer error: job={} user={} printer={}".format(
                job.doc_name,
                job.user,
                job.printer,
            )
        )
        syslog(err_msg)
        send_problem_report(err_msg)
        send_notification(wayout_pass, "Printer Error", msg, job.user)
    r.publish("user-" + job.user, msg)


def main(argv):
    if len(argv) == 1:
        sys.exit(CUPS_BACKEND_OK)

    if len(argv) < 6:
        print(
            "Usage: {} job-id user title copies options [file]".format(argv[0]),
            file=sys.stderr,
        )
        sys.exit(CUPS_BACKEND_FAILED)

    tmp_file = None
    job = None
    quo = None

    try:
        mysql_pass, redis_host, redis_pass, wayout_pass = read_config()
        r = redis.StrictRedis(
            host=redis_host,
            port=6378,
            password=redis_pass,
            ssl=True,
        )

        job, filepath, tmp_file = get_job_and_filepath(argv)

        with quota.get_connection(user="ocfprinting", password=mysql_pass) as c:
            ok, quo = do_prehook(c, r, job, filepath, wayout_pass)
            if not ok:
                sys.exit(CUPS_BACKEND_CANCEL)

            success = forward_to_printer(argv, filepath)

            do_posthook(c, r, job, quo, success, wayout_pass)
            sys.exit(CUPS_BACKEND_OK if success else CUPS_BACKEND_FAILED)

    except SystemExit:
        raise
    except Exception:
        msg = dedent("""\
            enforcer backend encountered an error:

            {traceback}

            CUPS environment:
            {env}
            """).format(
            traceback=format_exc(),
            env="\n".join(
                "  {}: {}".format(k, v)
                for k, v in os.environ.items()
                if k in ("PRINTER", "CLASS", "DEVICE_URI", "CONTENT_TYPE")
            ),
        )
        syslog(msg)
        try:
            send_problem_report(msg)
        except Exception:
            pass
        if job is not None:
            try:
                send_printer_mail(
                    ENFORCER_ERROR_MESSAGE_SUBJECT,
                    ENFORCER_ERROR_MESSAGE_BODY,
                    job,
                    quo
                    or quota.UserQuota(
                        user=job.user,
                        daily="Unknown",
                        semesterly="Unknown",
                        color="Unknown",
                    ),
                )
            except Exception:
                pass
        sys.exit(CUPS_BACKEND_CANCEL)

    finally:
        if tmp_file and os.path.exists(tmp_file):
            os.unlink(tmp_file)


if __name__ == "__main__":
    main(sys.argv)
