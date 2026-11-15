# Verify

Run these in the repo folder before marking a change done.

```bash
bash -n Mac/install.sh Mac/bootstrap.sh Mac/transcribe.sh Mac/settings/fonts-sync.sh
python3 -m py_compile Mac/settings/font_sync.py Mac/settings/font_names.py
```

Both commands print nothing and exit 0 when the scripts parse.
