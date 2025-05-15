# S3 Encrypted Backup Container

A Docker container for performing periodic backups to S3-compatible storage using GPG encryption.

## Features

- Automated backups to any S3-compatible storage
- GPG encryption
- Timestamp-based backup naming
- Healthchecks.io integration

## Requirements

- Docker
- Access to an S3-compatible storage service
- AWS credentials with write access to the target bucket

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BACKUP_NAME` | Yes | Base name for your backup files |
| `PASSWORD` | Yes | Passphrase for GPG encryption |
| `AWS_ENDPOINT_URL` | Yes | S3 endpoint URL |
| `S3_BUCKET_URL` | Yes | Full S3 bucket URL (s3://bucket-name/optional-prefix/) |
| `CRON_SCHEDULE` | Yes | Crontab schedule for backup execution |
| `AWS_ACCESS_KEY_ID` | Yes | S3 access key |
| `AWS_SECRET_ACCESS_KEY` | Yes | S3 secret key |
| `TARGET` | No | Directory to backup (default: `/data`) |
| `HEALTHCHECK_URL` | No | Optional URL for health check pings (https://healthchecks.io/) |

## Usage

### Using Prebuilt Image

You can use the prebuilt Docker image from GitHub Container Registry:

```bash
docker pull ghcr.io/helsus/backup:latest
```

### Building the Image

Alternatively, you can build the image yourself:

```bash
docker build -t s3-backup .
```

### Running the Container

Basic example:

```bash
docker run -d \
  -e BACKUP_NAME="my-backup" \
  -e PASSWORD="secure-password" \
  -e AWS_ENDPOINT_URL="https://s3.example.com" \
  -e S3_BUCKET_URL="s3://my-backup-bucket/backups/" \
  -e CRON_SCHEDULE="0 2 * * *" \
  -e AWS_ACCESS_KEY_ID="your-access-key" \
  -e AWS_SECRET_ACCESS_KEY="your-secret-key" \
  -v /path/to/data:/data \
  s3-backup
```

### Docker Compose Example

```yaml
services:
  backup:
    build: .
    environment:
      - BACKUP_NAME=my-backup
      - PASSWORD=secure-password
      - AWS_ENDPOINT_URL=https://s3.example.com
      - S3_BUCKET_URL=s3://my-backup-bucket/backups/
      - CRON_SCHEDULE=0 2 * * *
      - AWS_ACCESS_KEY_ID=your-access-key
      - AWS_SECRET_ACCESS_KEY=your-secret-key
      - HEALTHCHECK_URL=https://hc-ping.com/your-uuid
    volumes:
      - /path/to/data:/data
    restart: unless-stopped
```

## Backup Naming Strategy

The container implements a timestamp-based naming strategy:

- Each backup is saved with the format: `BACKUP_NAME-YYYY-MM-DD--HHMMSS.tar.gz.enc`
- This naming convention allows for:
  - Easy chronological sorting of backups
  - Clear identification of backup date and time
  - Simple management of retention policies

You can implement custom rotation strategies using external tools or scripts that delete older backups based on your retention requirements. (e.g. [Object Lifecycle Rules](https://developers.cloudflare.com/r2/buckets/object-lifecycles/))

## Health Checks

When providing a `HEALTHCHECK_URL`, the container will:

1. Send a start ping with `?rid=<unique-id>` when a backup begins
2. Send a success ping when the backup completes successfully
3. Send a failure ping with the exit code when a backup fails

This is compatible with [Healthchecks.io](https://healthchecks.io).

## Restoring Backups

To restore a backup, you need to:

1. Download the encrypted backup file from S3
2. Decrypt it using GPG with the same password
3. Extract the contents

```bash
# Download
aws s3 cp --endpoint-url "https://s3.example.com" "s3://my-bucket/my-backup-2023-01-01--120000.tar.gz.enc" .

# Decrypt
gpg --decrypt --output "my-backup.tar.gz" "my-backup-2023-01-01--120000.tar.gz.enc"

# Extract
tar -xzf my-backup.tar.gz -C /path/to/restore
```
