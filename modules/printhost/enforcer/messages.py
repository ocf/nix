from textwrap import dedent
from typing import NamedTuple

from ocflib.misc.mail import MAIL_SIGNATURE


class Message(NamedTuple):
    subject: str
    body: str


class MessagePair(NamedTuple):
    message: Message | None
    notification: Message


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
    subject="[OCF] Your latest print job was rejected",
    body=dedent("""\
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
    + MAIL_SIGNATURE,
)

INSUFFICIENT_COLOR_QUOTA_MESSAGE = Message(
    subject="[OCF] Your latest print job was rejected",
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is letting you know that your most recent print job was
        rejected since it would exceed your color printing quota. The color
        printing quota is {color_quota} pages and the semesterly quota is
        {semester_quota} pages.

        """)
    + USER_ERROR_INFO
    + dedent("""

        Does something look wrong? Please reply to

            help@ocf.berkeley.edu


        """)
    + MAIL_SIGNATURE,
)

PRINTER_ERROR_MESSAGE = Message(
    subject="[OCF] Your latest print job failed",
    body=dedent("""\
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
    + MAIL_SIGNATURE,
)

ENFORCER_ERROR_MESSAGE = Message(
    subject="[OCF] Your latest print job failed",
    body=dedent("""\
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
    + MAIL_SIGNATURE,
)

NON_LETTER_ERROR_MESSAGE = Message(
    subject="[OCF] Your latest print job failed",
    body=dedent("""\
        Greetings from the Open Computing Facility,

        This email is letting you know that your most recent print job was
        rejected since it was not letter sized. Please ensure that you are
        following all instructions on the computers.

        """)
    + USER_ERROR_INFO
    + dedent("""

        Does something look wrong? Please reply to

            help@ocf.berkeley.edu

        """)
    + MAIL_SIGNATURE,
)


NOTIFY_QUOTA = Message(
    subject="Insufficient Quota",
    body=dedent("""\
        Your print job failed due to insufficient pages. Your job was
        {pages} pages, and you have {quota} pages remaining today.\
"""),
)

NOTIFY_COLOR_QUOTA = Message(
    subject="Insufficient Color Quota",
    body=dedent("""\
        Your print job failed due to insufficient color quota. Your job was
        {pages} pages, and you have {quota} color pages remaining today.\
"""),
)

NOTIFY_JOB_QUEUED = Message(
    subject="Job Queued",
    body=dedent("""\
        Your print job '{document}' was accepted and queued on '{printer}'.\
"""),
)
NOTIFY_JOB_ERROR = Message(
    subject="Print Error",
    body=dedent("""\
        Your print job '{document}' failed due to a printer error.
        Please contact a staff member for assistance.\
"""),
)

NOTIFY_ENFORCER_ERROR = Message(
    subject="Print Error",
    body=dedent("""\
        Your print job '{document}' failed due to a printing system error.
        Please contact a staff member for assistance.\
"""),
)

NOTIFY_NON_LETTER = Message(
    subject="Non Letter Error",
    body=dedent("""\
        Your print job '{document}' failed due to not being letter sized.\
"""),
)


# Reasons
INSUFFICIENT_QUOTA = MessagePair(
    message=INSUFFICIENT_QUOTA_MESSAGE,
    notification=NOTIFY_QUOTA,
)
INSUFFICIENT_COLOR_QUOTA = MessagePair(
    message=INSUFFICIENT_COLOR_QUOTA_MESSAGE,
    notification=NOTIFY_COLOR_QUOTA,
)
PRINTER_ERROR = MessagePair(
    message=PRINTER_ERROR_MESSAGE,
    notification=NOTIFY_JOB_ERROR,
)
ENFORCER_ERROR = MessagePair(
    message=ENFORCER_ERROR_MESSAGE,
    notification=NOTIFY_ENFORCER_ERROR,
)
NON_LETTER_ERROR = MessagePair(
    message=NON_LETTER_ERROR_MESSAGE,
    notification=NOTIFY_NON_LETTER,
)
JOB_QUEUED = MessagePair(
    message=None,
    notification=NOTIFY_JOB_QUEUED,
)
