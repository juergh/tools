import logging

DEBUG = logging.DEBUG
INFO = logging.INFO
WARNING = logging.WARNING
ERROR = logging.ERROR
CRITICAL = logging.CRITICAL

log = logging.getLogger("ukalib")
if not log.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("%(name)s:%(levelname)s - %(message)s")
    handler.setFormatter(formatter)
    log.addHandler(handler)
    log.setLevel(ERROR)


def set_log_level(level):
    log.setLevel(level)
