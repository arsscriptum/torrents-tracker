# Database Notes

### schema_version table

```sql
CREATE TABLE schema_version (
    id INT PRIMARY KEY AUTO_INCREMENT,
    version_number VARCHAR(50) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    script_name VARCHAR(255)
);
```

### magnet_links table


```sql
CREATE TABLE "magnet_links" (
    "id"            integer NOT NULL,
    "DateAdded"     datetime NOT NULL,
    "AbsolutePath"  varchar(512) NOT NULL,
    "AbsoluteUri"   varchar(512) NOT NULL,
    "Authority"     varchar(512) NOT NULL,
    "Host"          varchar(128) NOT NULL,
    "Port"          integer NOT NULL,
    "Scheme"        varchar(32) NOT NULL, "Version" integer,
    PRIMARY KEY("id" AUTOINCREMENT)
)

ALTER TABLE magnet_links
ADD COLUMN "Version" integer;

UPDATE magnet_links
SET Version = 1;

```
