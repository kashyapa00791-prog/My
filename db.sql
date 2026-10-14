
CREATE DATABASE IF NOT EXISTS license_manager
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE license_manager;

CREATE TABLE IF NOT EXISTS tiers (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tier_name VARCHAR(32) NOT NULL UNIQUE,
    features_json TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(128) DEFAULT NULL,
    license_key VARCHAR(64) NOT NULL UNIQUE,
    tier VARCHAR(32) NOT NULL DEFAULT 'basic',
    expires_at DATETIME NOT NULL,
    is_banned TINYINT(1) NOT NULL DEFAULT 0,
    ban_reason VARCHAR(255) DEFAULT NULL,
    max_devices INT UNSIGNED NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME DEFAULT NULL,
    INDEX idx_users_expiry (expires_at),
    INDEX idx_users_banned (is_banned),
    INDEX idx_users_tier (tier),
    CONSTRAINT fk_users_tier
        FOREIGN KEY (tier) REFERENCES tiers(tier_name)
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS devices (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    device_hash VARCHAR(128) NOT NULL,
    device_name VARCHAR(128) DEFAULT NULL,
    first_seen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_user_device (user_id, device_hash),
    INDEX idx_device_hash (device_hash),
    CONSTRAINT fk_devices_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    token CHAR(64) NOT NULL UNIQUE,
    device_hash VARCHAR(128) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    INDEX idx_session_user_expiry (user_id, expires_at),
    INDEX idx_session_device (device_hash),
    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED DEFAULT NULL,
    action VARCHAR(64) NOT NULL,
    device_hash VARCHAR(128) DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    extra TEXT DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_time (user_id, created_at),
    INDEX idx_action_time (action, created_at),
    CONSTRAINT fk_logs_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS keys_pool (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    license_key VARCHAR(64) NOT NULL UNIQUE,
    tier VARCHAR(32) NOT NULL DEFAULT 'basic',
    duration_days INT UNSIGNED NOT NULL DEFAULT 30,
    is_used TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME DEFAULT NULL,
    INDEX idx_keys_unused (is_used, created_at),
    CONSTRAINT fk_keys_tier
        FOREIGN KEY (tier) REFERENCES tiers(tier_name)
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    was_successful TINYINT(1) NOT NULL DEFAULT 0,
    INDEX idx_admin_attempt_ip (ip_address, attempted_at),
    INDEX idx_admin_attempt_user (username, attempted_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS api_login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45) NOT NULL,
    username VARCHAR(64) NOT NULL DEFAULT '',
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    was_successful TINYINT(1) NOT NULL DEFAULT 0,
    INDEX idx_api_attempt_ip (ip_address, attempted_at),
    INDEX idx_api_attempt_user (username, attempted_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settings (
    setting_key VARCHAR(64) PRIMARY KEY,
    setting_value TEXT NOT NULL,
    updated_at DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO tiers
    (tier_name, features_json, display_order)
VALUES
    ('basic', '["standard_access"]', 1),
    ('pro', '["standard_access","advanced_access"]', 2),
    ('elite', '["standard_access","advanced_access","priority_access"]', 3),
    ('vip', '["standard_access","advanced_access","priority_access","premium_support"]', 4);

INSERT IGNORE INTO settings (setting_key, setting_value)
VALUES
    ('maintenance_mode', '0');
