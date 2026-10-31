import os
import yaml

PATH = "/data/homeserver.yaml"

with open(PATH) as f:
    cfg = yaml.safe_load(f)

cfg["database"] = {
    "name": "psycopg2",
    "args": {
        "user": "synapse",
        "password": os.environ["POSTGRES_PASSWORD"],
        "database": "synapse",
        "host": "db",
        "cp_min": 5,
        "cp_max": 10,
    },
}
cfg["public_baseurl"] = "https://%s/" % os.environ["SYNAPSE_SERVER_NAME"]
cfg["enable_registration"] = False

# Behind Caddy: trust X-Forwarded-* on the plain-HTTP listener.
for listener in cfg.get("listeners", []):
    if listener.get("type") == "http":
        listener["x_forwarded"] = True

with open(PATH, "w") as f:
    yaml.safe_dump(cfg, f, sort_keys=False)
print("homeserver.yaml patched")
