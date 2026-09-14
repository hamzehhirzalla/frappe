"""Initialize local runtime defaults without creating company or transaction data."""
import os
import frappe
from frappe.utils.password import get_encryption_key

os.chdir("/home/frappe/frappe-bench/sites")
frappe.init(site="frappe.localhost", sites_path=".")
frappe.connect()
frappe.set_user("Administrator")
try:
    # Frappe creates this lazily; initialize it before the first exported backup.
    get_encryption_key()
    settings = frappe.get_single("System Settings")
    settings.time_zone = "Asia/Dubai"
    settings.language = settings.language or "en"
    settings.save()
    insights = frappe.get_single("Insights Settings")
    insights.enable_permissions = 1
    insights.apply_user_permissions = 1
    insights.save()
    frappe.db.commit()
    frappe.clear_cache()
    print("Initialized site encryption key, Dubai timezone, and Insights permissions.")
finally:
    frappe.destroy()
