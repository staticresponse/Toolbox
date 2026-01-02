from pathlib import Path
from datetime import datetime
import shutil

# --- Paths ---
DOWNLOADS_DIR = Path(r"C:\Users\Mike\Downloads")
LOG_FILE = Path(r"C:\Users\Mike\Desktop\download.txt")

DESTINATIONS = {
    ".ppt":  Path(r"E:\presentations"),
    ".pptx": Path(r"E:\presentations"),
    ".xlsx": Path(r"E:\excel"),
    ".csv":  Path(r"E:\excel"),
    ".doc":  Path(r"E:\docs"),
    ".docx": Path(r"E:\docs"),
    ".pdf":  Path(r"E:\pdfArchive"),
    ".png":  Path(r"C:\Users\Mike\Pictures"),
    ".jpg":  Path(r"C:\Users\Mike\Pictures"),
    ".jpeg": Path(r"C:\Users\Mike\Pictures"),
    ".gif":  Path(r"C:\Users\Mike\Pictures"),
    ".r":    Path(r"E:\R_code"),
}

DELETE_EXTENSIONS = {
    ".zip",
    ".exe",
    ".msi",
}

# --- Script ---
def main():
    now = datetime.now()
    files_checked = 0

    # Ensure destination directories exist
    for path in DESTINATIONS.values():
        path.mkdir(parents=True, exist_ok=True)

    with LOG_FILE.open("a", encoding="utf-8") as log:
        log.write(f"{now} - Starting Download Cleanup Script.\n")

        for file in DOWNLOADS_DIR.iterdir():
            if not file.is_file():
                continue

            files_checked += 1
            ext = file.suffix.lower()

            try:
                if ext in DESTINATIONS:
                    shutil.move(str(file), DESTINATIONS[ext])
                elif ext in DELETE_EXTENSIONS:
                    file.unlink()
            except Exception as e:
                log.write(f"{datetime.now()} - ERROR processing {file.name}: {e}\n")

        log.write(f"{datetime.now()} - Files Checked {files_checked}.\n")


if __name__ == "__main__":
    main()
