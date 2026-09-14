"""Run with the bench Python inside backend to check apps, schemas, and real workers."""
import importlib
import json
import os
import time
import uuid

import frappe

os.chdir("/home/frappe/frappe-bench/sites")
frappe.init(site="frappe.localhost", sites_path="/home/frappe/frappe-bench/sites")
frappe.connect()
frappe.set_user("Administrator")
try:
    expected = {"frappe", "erpnext", "hrms", "crm", "lending", "insights", "telephony", "helpdesk"}
    installed = set(frappe.get_installed_apps())
    assert expected <= installed, installed
    versions = {app: importlib.import_module(app).__version__ for app in sorted(expected)}
    for doctype in ["Company", "Employee", "Salary Slip", "CRM Lead", "Loan", "Insights Workbook", "HD Ticket", "HD Team", "HD Agent", "TP Call Log"]:
        assert frappe.db.exists("DocType", doctype), doctype
        frappe.db.count(doctype)
    assert frappe.conf.server_script_enabled
    assert not frappe.conf.pause_scheduler
    assert frappe.db.get_single_value("System Settings", "enable_scheduler")
    from helpdesk.search import HelpdeskSearch

    assert HelpdeskSearch().index_exists(), "Helpdesk knowledge-base search index is missing"
    assert frappe.db.count("HD Ticket Status", {"enabled": 1}) > 0
    assert frappe.db.count("HD Ticket Priority") > 0
    from frappe.utils.background_jobs import enqueue

    jobs = []
    for queue in ["short", "long"]:
        job = enqueue("frappe.utils.now", queue=queue, job_id="installation-check-" + uuid.uuid4().hex)
        jobs.append((queue, job))
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if all(job.get_status(refresh=True) == "finished" for _, job in jobs):
            break
        if any(job.get_status(refresh=True) == "failed" for _, job in jobs):
            raise RuntimeError("Worker verification job failed")
        time.sleep(1)
    for queue, job in jobs:
        assert job.get_status(refresh=True) == "finished", f"{queue} worker did not complete the job"
        job.delete()
    print(json.dumps({"apps": versions, "schemas": "passed", "helpdesk_search": "passed", "helpdesk_ticket_defaults": "passed", "short_worker": "passed", "long_worker": "passed", "scheduler": "enabled", "company_setup_complete": bool(frappe.db.get_single_value("System Settings", "setup_complete"))}, indent=2))
finally:
    frappe.destroy()
