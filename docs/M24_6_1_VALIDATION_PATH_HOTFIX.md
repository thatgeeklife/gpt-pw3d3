# M24.6.1 Validation Path Hotfix

M24.6 correctly refreshed the Validation Report, but Asset Health could still report generated wrappers as missing because it used a stricter/less defensive file existence check than the wrapper builder used after writing files.

M24.6.1 makes validation use the same stronger absolute-path check and adds the resolved absolute paths to the report.

When diagnosing a missing wrapper, check these lines in Asset Health:

```text
Stored Path: res://assets/theme_imports/walls/wall_wrapper.tscn
Resolved Absolute Path: .../GameProject/assets/theme_imports/walls/wall_wrapper.tscn
File Exists: YES/NO
```

If File Exists is still NO, the report now shows the exact filesystem location where the tool expected the wrapper to be.
