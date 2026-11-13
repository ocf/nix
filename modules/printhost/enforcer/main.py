import threading
import time
from pathlib import PurePosixPath
from syslog import syslog
from urllib.parse import urlparse

import cups
from enforcer import *
from utils import *


def process_new_jobs(conn, job_data, job_id_list):
    # jobs = conn.getJobs(
    #     which_jobs="not-completed",
    #     requested_attributes=[
    #         "job-id",
    #         "job-name",
    #         "job-originating-user-name",
    #         "job-originating-host-name",
    #         "print-color-mode",
    #         "job-printer-uri-actual",
    #         "job-printer-uri",
    #         "copies",
    #     ],
    # )

    for job_id in job_id_list:
        try:
            job_attributes = conn.getJobAttributes(
                job_id,
                requested_attributes=[
                    "job-id",
                    "job-name",
                    "job-uuid",
                    "job-originating-user-name",
                    "job-originating-host-name",
                    "print-color-mode",
                    "job-printer-uri-actual",
                    "job-printer-uri",
                    "copies",
                ],
            )
            job_name = job_attributes.get("job-name", "Unknown")
            job_uuid = job_attributes.get("job_uuid", "Unknown")
            user = job_attributes.get("job-originating-user-name", "Unknown")
            host = job_attributes.get("job-originating-host-name", "Unknown")
            color = job_attributes.get("print-color-mode", "Unknown")
            copies = job_attributes.get("copies")
            if not copies:
                copies = 1
            else:
                copies = int(copies)
            printer_uri = job_attributes.get("job-printer-uri-actual")
            if not printer_uri:
                printer_uri = job_attributes.get("job-printer-uri")
            printer = PurePosixPath(urlparse(printer_uri).path).name

            syslog(
                f"Job #{job_id} | Printer: {printer} | User: {user} | Title: {job_name} | Host: {host} | Color: {color}"
            )

            job = Job(
                id=int(job_id),
                user=user,
                document_title=job_name,
                printer_name=printer,
                printer_uri=printer_uri,
                hostname=host,
                time=datetime.now(),
                copies=copies,
                color=(color == "color"),
                uuid=job_uuid,
            )

            t = threading.Thread(
                target=enforce_print_init,
                args=(
                    job_data,
                    job,
                ),
                name=f"job-{job_id}",
            )
            t.start()
        except cups.IPPError:
            syslog(f"Job #{job_id} | failed to get data")


def process_completed_jobs(conn, job_data, job_id_list):
    for job_id in job_id_list:
        try:
            job_attributes = conn.getJobAttributes(
                job_id,
                requested_attributes=[
                    "job-id",
                    "job-state",
                    "job-uuid",
                ],
            )

            job_state = job_attributes.get("job-state", "Unknown")
            job_uuid = job_attributes.get("job_uuid", "Unknown")

            job = Job(
                id=int(job_id),
                uuid=job_uuid,
            )

            if job_state == cups.IPP_JOB_COMPLETED:
                # job completed successfully
                t = threading.Thread(
                    target=post_print,
                    args=(
                        job_data,
                        job,
                    ),
                    name=f"job-complete-{job_id}",
                )
                t.start()
            else:
                syslog(f"Job #{job_id} | failed to print")
                # job failed
                pass

        except cups.IPPError:
            syslog(f"Job #{job_id} | failed to get data")


def get_initial_jobs(conn):
    all_active_jobs = conn.getJobs(
        which_jobs="not-completed", requested_attributes=["job-id", "job-state"]
    )
    held_jobs = []
    for job_id, job_info in all_active_jobs.items():
        if job_info.get("job-state") == cups.IPP_JOB_HELD:
            held_jobs.append(job_id)
    return held_jobs


def monitor_cups_jobs(conn, job_data):
    sub_id = conn.createSubscription(
        uri="/",
        events=["job-created", "job-completed"],
    )

    sequence_num = 1

    try:
        while True:
            data = conn.getNotifications([sub_id], [sequence_num])
            notifications = data.get("events", [])

            new_job_ids = []
            completed_job_ids = []
            max_seq = sequence_num

            for notify in notifications:
                job_id = notify.get("notify-job-id")
                reason = notify.get("notify-subscribed-event")

                seq = notify.get("notify-sequence-number")
                if seq and seq >= max_seq:
                    max_seq = seq + 1

                if job_id:
                    if reason == "job-created":
                        new_job_ids.append(job_id)
                    elif reason == "job-completed":
                        completed_job_ids.append(job_id)
                else:
                    syslog("failed to get job id")

            process_new_jobs(conn, job_data, new_job_ids)
            process_completed_jobs(conn, job_data, completed_job_ids)

            sequence_num = max(sequence_num, max_seq)

            time.sleep(1)

    finally:
        try:
            conn.cancelSubscription(sub_id)
        except cups.IPPError:
            pass


if __name__ == "__main__":
    conn = cups.Connection()

    job_data = {}  # init shared job data dict

    process_new_jobs(conn, job_data, get_initial_jobs(conn))
    monitor_cups_jobs(conn, job_data)
