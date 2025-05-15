#!/bin/sh

set -e

: "${TARGET:=/data}"

if [[ -z "$BACKUP_NAME" ]]; then
  echo "Error: BACKUP_NAME environment variable is not set." >&2
  exit 1
fi
if [[ -z "$PASSWORD" ]]; then
  echo "Error: PASSWORD environment variable is not set." >&2
  exit 1
fi
if [[ -z "$AWS_ENDPOINT_URL" ]]; then
  echo "Error: AWS_ENDPOINT_URL environment variable is not set." >&2
  exit 1
fi
if [[ -z "$S3_BUCKET_URL" ]]; then
  echo "Error: S3_BUCKET_URL environment variable is not set." >&2
  exit 1
fi

if [[ ! -e "$TARGET" ]]; then
    echo "Error: Target '$TARGET' not found." >&2
    exit 1
fi


send_ping() {
    if [[ -n "$HEALTHCHECK_URL" ]]; then
        local suffix="$1"
        local url="$HEALTHCHECK_URL"

        if [[ -n "$suffix" ]]; then
            url=$(echo "$url" | sed 's:/*$::')/$suffix
        fi

        if [[ -n "$RID" ]]; then
            if echo "$url" | grep -q '?'; then
                url="$url&rid=$RID"
            else
                url="$url?rid=$RID"
            fi
        fi

        echo "Pinging health check URL: $url"
        curl -fsS -m 10 --retry 5 -o /dev/null "$url" || echo "Warning: Health check ping failed for URL: $url"
    fi
}

handle_exit() {
    local exit_status=$?
    echo "Performing cleanup..."
    rm -f "$TMP_ENC_FILE" "$TMP_TAR_FILE"
    echo "Cleanup finished."

    if [[ "$exit_status" -ne 0 ]]; then
        echo "Script failed with exit code $exit_status."
        send_ping "$exit_status" # Send exit code as status suffix on failure
    else
        echo "Backup process completed successfully."
        send_ping "" # Empty suffix indicates success
    fi
    echo "Done."
}

upload_backup() {
    local s3_object_name="$1"
    local s3_dest_url="${S3_BUCKET_URL_BASE}${s3_object_name}"

    echo "Uploading backup to S3 [$TMP_ENC_FILE] -> [$s3_dest_url]..."
    aws s3 cp --endpoint-url "$AWS_ENDPOINT_URL" "$TMP_ENC_FILE" "$s3_dest_url"
    echo "upload complete."
}


trap handle_exit EXIT

RID=""

if [[ -n "$HEALTHCHECK_URL" ]]; then
    echo "Generating RID (UUID format)..."
    if [ -r /proc/sys/kernel/random/uuid ]; then
        RID=$(cat /proc/sys/kernel/random/uuid)
        echo "Generated RID: $RID"
        send_ping "start"
    else
        echo "Warning: /proc/sys/kernel/random/uuid not found or not readable. Cannot generate RID or send start ping."
    fi
fi

S3_BUCKET_URL_BASE=$(echo "$S3_BUCKET_URL" | sed 's:/*$:/:' )

SLOT=$(date +%Y-%m-%d--%H%M%S)

S3_OBJECT_NAME="$BACKUP_NAME-$SLOT.tar.gz.enc"

TMP_DIR="/tmp"
if [ ! -d "$TMP_DIR" ] || [ ! -w "$TMP_DIR" ]; then
    echo "Error: Temporary directory '$TMP_DIR' not found or not writable." >&2
    exit 1
fi
TMP_FILE_BASE="$TMP_DIR/$BACKUP_NAME-$(date "+%s")"
TMP_TAR_FILE="$TMP_FILE_BASE.tar.gz"
TMP_ENC_FILE="$TMP_TAR_FILE.enc"

echo "Using target: $TARGET"
echo "Temporary archive file: $TMP_TAR_FILE"
echo "Temporary encrypted file: $TMP_ENC_FILE"

echo "Creating archive..."
if [ -d "$TARGET" ]; then
  PARENT_DIR=$(dirname "$TARGET")
  BASE_NAME=$(basename "$TARGET")
  tar --gzip -cf "$TMP_TAR_FILE" -C "$PARENT_DIR" "$BASE_NAME"
else
  tar --gzip -cf "$TMP_TAR_FILE" "$TARGET"
fi
echo "Archive created."

echo "Encrypting archive..."
gpg --passphrase "$PASSWORD" --batch --yes --output "$TMP_ENC_FILE" --symmetric "$TMP_TAR_FILE"
echo "Encryption complete."

rm -f "$TMP_TAR_FILE"

upload_backup "$S3_OBJECT_NAME"

echo "Backup process finished."
