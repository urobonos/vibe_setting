content = open("C:/Works/hongcafe_global_backend/docs/output/_write_audit_v3.py.content", "r", encoding="utf-8").read()
with open("C:/Works/hongcafe_global_backend/docs/output/http-status-code-audit_20260414.md", "w", encoding="utf-8") as f:
    f.write(content)
print(f"Written {len(content)} bytes")
