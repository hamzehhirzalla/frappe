"""Validate the installed Insights site data source and inspect installation errors."""
import json
import os
import frappe

os.chdir("/home/frappe/frappe-bench/sites")
frappe.init(site="frappe.localhost", sites_path=".")
frappe.connect()
frappe.set_user("Administrator")
try:
    from insights.insights.doctype.insights_data_source_v3.insights_data_source_v3 import db_connections
    source = frappe.get_doc("Insights Data Source v3", {"is_site_db": 1})
    settings = frappe.get_single("Insights Settings")
    assert settings.enable_permissions and settings.apply_user_permissions
    with db_connections():
        assert source.test_connection(), "Insights could not query its site database"
    errors = frappe.get_all("Error Log", fields=["method", "creation"], limit_page_length=10)
    print(json.dumps({"insights_site_database": "passed", "insights_permissions": "enabled", "recent_errors": errors}, default=str, indent=2))
finally:
    frappe.destroy()
