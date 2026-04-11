#!/usr/bin/env python3
"""Enforcer is a prehook and posthook for the ocf-cups-backend whose primary
purpose is to add and subtract from page quotas as user jobs are processed.

When a user sends a job to the print server, the backend calls enforcer before
sending it to the printer. Enforcer reads the job-impressions CUPS attribute to
count pages and connects to mysql to check against the user's quota. If enforcer
returns non-zero, the job is rejected. Otherwise, enforcer gets called again when
the job is done and logs the job in mysql.

Another function of enforcer is to send notifications to desktops to let users
know when a job has been sent to the printer, been rejected due to the quota,
finished printing, or failed to print.
"""
import argparse
import os
import sys
import re
import subprocess
from pathlib import Path
from collections import namedtuple
from datetime import datetime
from syslog import syslog
from textwrap import dedent
from traceback import format_exc

import ocflib.printing.quota as quota
import redis
import requests
from ocflib.misc.mail import MAIL_SIGNATURE
from ocflib.misc.mail import send_mail_user
from ocflib.misc.mail import send_problem_report


# Redis broker for real-time notifications
REDIS_HOST = 'broker.ocf.berkeley.edu'
REDIS_PORT = 6378

COLOR_QUEUES = {'OCF-Color'}

APP_NAME = 'Printer'
PORT = 6767

Message = namedtuple('Message', ['subject', 'body'])


USER_ERROR_INFO = dedent("""\
    Username: {user}
    Time: {time}
    File: {doc_name}
    Total pages: {pages}
    Pages left today: {daily_pages}
    Pages left this semester: {semester_pages}
    Color pages left: {color_pages}\
""")

INSUFFICIENT_QUOTA_MESSAGE = Message(
    subject='[OCF] Your latest print job was rejected',
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is letting you know that your most recent print job was
        rejected since it would exceed your daily quota. The daily quota is
        {daily_quota} pages today and the semesterly quota is {semester_quota} pages.

        """) + USER_ERROR_INFO + dedent("""

        Does something look wrong? Please reply to

            help@ocf.berkeley.edu


        """) + MAIL_SIGNATURE
)

INSUFFICIENT_COLOR_QUOTA_MESSAGE = Message(
    subject='[OCF] Your latest print job was rejected',
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is letting you know that your most recent print job was
        rejected since it would exceed your color printing quota. The color
        printing quota is {color_quota} pages and the semesterly quota is
        {semester_quota} pages.

        """) + USER_ERROR_INFO + dedent("""

        Does something look wrong? Please reply to

            help@ocf.berkeley.edu


        """) + MAIL_SIGNATURE
)

PRINTER_ERROR_MESSAGE = Message(
    subject='[OCF] Your latest print job failed',
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is from the OCF to let you know that your most recent print
        job failed due to a printer error. If there's something wrong with the
        printers, please alert the operations staff at the desk.

        """) + USER_ERROR_INFO + dedent("""

        Still can't get it to print? Please reply to

            help@ocf.berkeley.edu


        """) + MAIL_SIGNATURE
)

ENFORCER_ERROR_MESSAGE = Message(
    subject='[OCF] Your latest print job failed',
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is from the OCF to let you know that your most recent print
        job failed due to a problem with the print accounting system. OCF staff
        have been notified of the problem and should fix it shortly. If there
        is a staff member in lab, you can ask them for help in the meantime.

        """) + USER_ERROR_INFO + dedent("""

        Still can't get it to print? Please reply to

            help@ocf.berkeley.edu


        """) + MAIL_SIGNATURE
)


NOTIFY_QUOTA_MESSAGE = dedent("""\
        Your print job failed due to insufficient pages. Your job was
        {pages} pages, and you have {quota} pages remaining today.\
""")

NOTIFY_COLOR_QUOTA_MESSAGE = dedent("""\
        Your print job failed due to insufficient color quota. Your job was
        {pages} pages, and you have {quota} color pages remaining today.\
""")

NOTIFY_JOB_QUEUED = dedent("""\
        Your print job '{document}' was accepted and queued on '{printer}'.\
""")

NOTIFY_JOB_ERROR = dedent("""\
        Your print job '{document}' failed due to a printer error.
        Please contact a staff member for assistance.\
""")


def read_config():
    with open(os.environ['ENFORCER_MYSQL_PASSWORD']) as f:
        mysql_passwd = f.read().strip()
    with open(os.environ['ENFORCER_REDIS_PASSWORD']) as f:
        redis_passwd = f.read().strip()
    with open(os.environ['ENFORCER_WAYOUT_PASSWORD']) as f:
        wayout_passwd = f.read().strip()
    return 'ocfprinting', mysql_passwd, redis_passwd, wayout_passwd


def page_count(env):
    filepath = env.get('TEADATAFILE')
    job_id = env.get('TEAJOBID')
    pages = 0
    copies = 1
    
    # 1. Grab copies directly from Tea4CUPS
    tea_copies = env.get('TEACOPIES')
    if tea_copies:
        try:
            copies = int(tea_copies)
        except ValueError:
            pass

    try:
        with open(filepath, 'rb') as f:
            header_chunk = f.read(4096)
            f.seek(0)

            # ==========================================
            # POSTSCRIPT PARSING LOGIC
            # ==========================================
            if b'%!' in header_chunk:
                for line in f:
                    if b'%%Pages:' in line or b'%RBINumCopies:' in line:
                        line_str = line.decode('utf-8', errors='ignore').strip()
                        
                        pages_match = re.search(r'^%%Pages:\s+(\d+)', line_str)
                        if pages_match:
                            pages = int(pages_match.group(1))
                        
                        # always use PostScript copies                        
                        copies_match = re.search(r'^%RBINumCopies:\s+(\d+)', line_str)
                        if copies_match:
                            copies = int(copies_match.group(1))

            # ==========================================
            # EJL / PDF LOGIC (Using qpdf)
            # ==========================================
            else:
                if job_id:
                    # Formats job 2 into 'd00002-001'
                    spool_filename = f"d{int(job_id):05}-001"
                    potential_path = os.path.join('/var/spool/cups', spool_filename)
                    
                    if os.path.exists(potential_path):
                        filepath = potential_path
                try:
                    # Call qpdf to get the number of pages. 
                    # --show-npages outputs just the integer (e.g., "5\n")
                    result = subprocess.run(
                        ['@qpdf@', '--show-npages', filepath],
                        capture_output=True,
                        text=True,
                        check=True
                    )
                    pages = int(result.stdout.strip())
                    
                except subprocess.CalledProcessError as e:
                    # qpdf will exit with an error if the file isn't a valid PDF
                    syslog(f"qpdf failed to parse {filepath}: {e.stderr.strip()}")
                    pass
                except FileNotFoundError:
                    syslog("qpdf is not installed or not in the system PATH.")
                    pass
                except ValueError:
                    syslog(f"qpdf returned non-integer output: {result.stdout}")
                    pass

    except Exception as e:
        syslog(f"Page count error: {e}")
        pass

    total_sides = pages * copies
    if total_sides <= 0:
        syslog(f"failed to get document sides (pages={pages}, copies={copies})")
        raise ValueError(f"failed to get document sides (pages={pages}, copies={copies})")
    return total_sides


def create_job(env):
    printer = env['TEAPRINTERNAME']
    queue = env['CLASS']
    return quota.Job(
        user=env['TEAUSERNAME'],
        time=datetime.now(),
        pages=page_count(env),
        queue=queue,
        printer=printer,
        doc_name=env['TEATITLE'],
        filesize=env['TEAJOBSIZE'],
    )


def send_printer_mail(message, job, quo):
    body = message.body.format(
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
    send_mail_user(job.user, message.subject, body)


def send_notification(wayout_pass, summary, body, username):
    try:
        hostname = get_hostname_from_username(username)
        if not hostname:
            return
        url = 'http://' + hostname + ':' + str(PORT) + '/notify'
        data = {
            'summary': summary,
            'body': body,
            'app_name': APP_NAME,
        }
        headers = {
            'Authorization': wayout_pass,
            'Content-Type': 'application/json'
        }
        requests.post(url=url, json=data, headers=headers, timeout=5)
    except Exception as e:
        syslog('Exception: ' + str(e))


def get_hostname_from_username(username):
    try:
        url = 'https://labmap.ocf.berkeley.edu/api/generate'
        res = requests.get(url, timeout=5).json()
        desktops = res.get('desktops', [])
        for desktop in desktops:
            if desktop.get('user', '') == username:
                return desktop.get('name')
        return None
    except Exception as e:
        syslog('Exception: ' + str(e))


def prehook(c, r, job, wayout_pass):
    quo = quota.get_quota(c, job.user)

    if job.pages > quo.daily:
        send_printer_mail(INSUFFICIENT_QUOTA_MESSAGE, job, quo)
        msg = NOTIFY_QUOTA_MESSAGE.format(
            pages=job.pages,
            quota=quo.daily,
        )
        r.publish('user-' + job.user, msg)
        send_notification(wayout_pass, 'Insufficient Quota', msg, job.user)
        sys.exit(255)
    elif job.queue in COLOR_QUEUES and job.pages > quo.color:
        send_printer_mail(INSUFFICIENT_COLOR_QUOTA_MESSAGE, job, quo)
        msg = NOTIFY_COLOR_QUOTA_MESSAGE.format(
            pages=job.pages,
            quota=quo.color,
        )
        r.publish('user-' + job.user, msg)
        send_notification(wayout_pass, 'Insufficient Color Quota', msg, job.user)
        sys.exit(255)


def posthook(c, r, job, success, wayout_pass):
    msg = ''
    if success:
        quota.add_job(c, job)
        msg = NOTIFY_JOB_QUEUED.format(
            document=job.doc_name,
            printer=job.printer
        )
        send_notification(wayout_pass, 'Job Queued', msg, job.user)
        r.publish('printer-' + job.printer, job.user)
    else:
        quo = quota.get_quota(c, job.user)
        msg = NOTIFY_JOB_ERROR.format(document=job.doc_name)
        send_printer_mail(PRINTER_ERROR_MESSAGE, job, quo)

        err_msg = dedent("""\
            enforcer encountered a printer error while processing a job

            backend environment variables:
            {vars}
            """).format(
            vars='\n'.join('  {}: {}'.format(k, v) for k, v in
                           os.environ.items() if k.startswith('TEA'))
        )

        syslog(err_msg)
        send_problem_report(err_msg)
        send_notification(wayout_pass, 'Printer Error', msg, job.user)
    r.publish('user-' + job.user, msg)


def main(argv):
    job, quo = None, None
    try:
        parser = argparse.ArgumentParser(
            description=__doc__,
            formatter_class=argparse.RawDescriptionHelpFormatter,
        )
        parser.add_argument('command',
                            choices={'prehook', 'posthook'})
        args = parser.parse_args(argv[1:])
        job = create_job(os.environ)
        mysql_user, mysql_pass, redis_pass, wayout_pass = read_config()
        r = redis.StrictRedis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=redis_pass,
            ssl=True,
        )
        with quota.get_connection(user=mysql_user, password=mysql_pass) as c:
            if args.command == 'prehook':
                prehook(c, r, job, wayout_pass)
            else:
                success = os.environ['TEASTATUS'] == '0'
                posthook(c, r, job, success, wayout_pass)
    except SystemExit as e:
        sys.exit(e.code)
    except Exception:
        msg = dedent("""\
            enforcer encountered the following error while processing a job:

            {traceback}


            backend environment variables:
            {vars}
            """).format(
            traceback=format_exc(),
            vars='\n'.join('  {}: {}'.format(k, v) for k, v in
                           os.environ.items() if k.startswith('TEA'))
        )

        syslog(msg)
        send_problem_report(msg)
        if job and args.command == 'prehook':
            try:
                send_printer_mail(
                    ENFORCER_ERROR_MESSAGE,
                    job,
                    quo or quota.UserQuota(user=job.user, daily='Unknown',
                                           semesterly='Unknown', color='Unknown')
                )
            except Exception:
                pass
        # Don't retry; it's not going to print the second time.
        sys.exit(255)


if __name__ == '__main__':
    main(sys.argv)
